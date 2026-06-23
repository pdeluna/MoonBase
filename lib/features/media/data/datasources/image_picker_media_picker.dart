import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Optional hook for reading a picked video's duration so the picker can
/// throw `MediaTooLongFailure` when the OS hands us a clip longer than
/// `MediaConstraints.videoMaxDuration`.
///
/// `image_picker`'s `maxDuration` parameter caps the OS UI on most platforms,
/// but is not honored everywhere (notably some Android pickers ignore it for
/// gallery picks). Plug in a `video_player`-based probe here when that
/// becomes a problem; default is conservative and skips the check.
typedef VideoDurationProbe = Future<Duration?> Function(String filePath);

/// `MediaPicker` backed by the `image_picker` plugin.
///
/// Phase 3 design:
///
/// 1. Raw pick via `ImagePicker().pickImage/pickVideo` (configurable
///    `ImageSource`).
/// 2. Bytes are read and capped against `MediaConstraints`. Over-cap →
///    `MediaTooLargeFailure`.
/// 3. (Video only) optional duration probe. Over-cap → `MediaTooLongFailure`.
/// 4. MIME is sniffed from headers and validated against the requested kind.
///    Mismatch → `MediaUnsupportedFailure`.
/// 5. A base-scoped, content-addressable storage key
///    (`<baseId>/<uuid>.<ext>`) is generated and written through
///    `MediaStorage.putBytes`.
/// 6. Returns a `MediaRef` with `syncStatus: SyncStatus.synced`
///    (Phase 3 is local-only; see `core/sync_status.dart`).
///
/// `captureFromCamera` is intentionally implemented as an `image_picker` +
/// `ImageSource.camera` wrapper. A Phase 4 `InAppCameraMediaPicker` is a
/// drop-in alternative `MediaPicker` implementation with the same contract.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.5.
class ImagePickerMediaPicker implements MediaPicker {
  ImagePickerMediaPicker({
    required this.storage,
    this.constraints = MediaConstraints.defaults,
    ImagePicker? imagePicker,
    VideoDurationProbe? videoDurationProbe,
    String Function()? idGenerator,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _videoDurationProbe = videoDurationProbe ?? _noopDurationProbe,
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  final MediaStorage storage;
  final MediaConstraints constraints;
  final ImagePicker _imagePicker;
  final VideoDurationProbe _videoDurationProbe;
  final String Function() _idGenerator;

  static Future<Duration?> _noopDurationProbe(String _) async => null;
  static String _defaultIdGenerator() => const Uuid().v4();

  @override
  Future<MediaRef?> pickImage(MediaPickRequest request) {
    assert(request.kind == MediaType.image,
        'pickImage requires MediaPickRequest.kind == image');
    return _runImagePick(
      request: request,
      pick: () => _imagePicker.pickImage(source: ImageSource.gallery),
    );
  }

  @override
  Future<MediaRef?> pickVideo(MediaPickRequest request) {
    assert(request.kind == MediaType.video,
        'pickVideo requires MediaPickRequest.kind == video');
    return _runVideoPick(
      request: request,
      pick: () => _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: request.effectiveMaxDuration(constraints),
      ),
    );
  }

  @override
  Future<MediaRef?> captureFromCamera(MediaPickRequest request) {
    if (request.kind == MediaType.video) {
      return _runVideoPick(
        request: request,
        pick: () => _imagePicker.pickVideo(
          source: ImageSource.camera,
          maxDuration: request.effectiveMaxDuration(constraints),
        ),
      );
    }
    return _runImagePick(
      request: request,
      pick: () => _imagePicker.pickImage(source: ImageSource.camera),
    );
  }

  // ---------------------------------------------------------------------------

  Future<MediaRef?> _runImagePick({
    required MediaPickRequest request,
    required Future<XFile?> Function() pick,
  }) async {
    final picked = await _invokeOsPicker(pick);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final maxBytes = request.effectiveMaxBytes(constraints);
    if (bytes.length > maxBytes) {
      throw const MediaTooLargeFailure();
    }

    final mimeType = _sniffMime(picked.path, bytes, fallback: 'image/jpeg');
    if (!mimeType.startsWith('image/')) {
      throw const MediaUnsupportedFailure();
    }

    final mediaId = MediaId(_idGenerator());
    final key = _composeKey(request.baseId, mediaId, picked.path, mimeType);
    await storage.putBytes(key: key, bytes: bytes, mimeType: mimeType);

    return MediaRef(
      id: mediaId,
      type: MediaType.image,
      storageKey: key,
      sizeBytes: bytes.length,
      mimeType: mimeType,
    );
  }

  Future<MediaRef?> _runVideoPick({
    required MediaPickRequest request,
    required Future<XFile?> Function() pick,
  }) async {
    final picked = await _invokeOsPicker(pick);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final maxBytes = request.effectiveMaxBytes(constraints);
    if (bytes.length > maxBytes) {
      throw const MediaTooLargeFailure();
    }

    final maxDuration = request.effectiveMaxDuration(constraints);
    final probed = await _videoDurationProbe(picked.path);
    if (probed != null && probed > maxDuration) {
      throw const MediaTooLongFailure();
    }

    final mimeType = _sniffMime(picked.path, bytes, fallback: 'video/mp4');
    if (!mimeType.startsWith('video/')) {
      throw const MediaUnsupportedFailure();
    }

    final mediaId = MediaId(_idGenerator());
    final key = _composeKey(request.baseId, mediaId, picked.path, mimeType);
    await storage.putBytes(key: key, bytes: bytes, mimeType: mimeType);

    return MediaRef(
      id: mediaId,
      type: MediaType.video,
      storageKey: key,
      duration: probed,
      sizeBytes: bytes.length,
      mimeType: mimeType,
    );
  }

  /// Wraps the OS picker call so the iOS / Android permission-denied
  /// `PlatformException`s surface as our domain `PermissionDeniedFailure`,
  /// which the UI layer knows how to render with an "Open Settings"
  /// affordance.
  Future<XFile?> _invokeOsPicker(Future<XFile?> Function() pick) async {
    try {
      return await pick();
    } on PlatformException catch (e) {
      if (_isPermissionDenied(e)) {
        throw PermissionDeniedFailure(e.message ?? 'Permission denied.');
      }
      rethrow;
    }
  }

  static bool _isPermissionDenied(PlatformException e) {
    // image_picker uses these codes across iOS / Android. Be defensive about
    // future code additions by also matching on substring.
    final code = e.code.toLowerCase();
    return code.contains('access_denied') ||
        code.contains('permission') ||
        code == 'camera_access_denied' ||
        code == 'photo_access_denied';
  }

  String _composeKey(
    BaseId baseId,
    MediaId mediaId,
    String sourcePath,
    String mimeType,
  ) {
    final ext = _extensionFor(sourcePath, mimeType);
    return '${baseId.value}/${mediaId.value}.$ext';
  }

  /// Header-based MIME sniffing with a small magic-number window. Falls back
  /// to [fallback] when nothing matches (rather than `null`) so the caller
  /// can still reject via the `image/` or `video/` prefix check.
  String _sniffMime(String path, List<int> bytes, {required String fallback}) {
    final headerBytes =
        bytes.length > defaultMagicNumbersMaxLength
            ? bytes.sublist(0, defaultMagicNumbersMaxLength)
            : bytes;
    return lookupMimeType(path, headerBytes: headerBytes) ?? fallback;
  }

  String _extensionFor(String sourcePath, String mimeType) {
    final fromPath = _extFromPath(sourcePath);
    if (fromPath != null) return fromPath;
    return _extFromMime(mimeType);
  }

  String? _extFromPath(String path) {
    final slash = path.lastIndexOf(RegExp(r'[\\/]'));
    final name = slash == -1 ? path : path.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    // Sanity: ignore absurdly long "extensions" (likely the rest of the URL).
    if (ext.length > 5 || ext.contains('?') || ext.contains('#')) return null;
    return ext;
  }

  String _extFromMime(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/webm':
        return 'webm';
      default:
        // Final fallback. Better to have an opaque ".bin" than no extension at
        // all — file readers will still load it via MIME hints.
        return 'bin';
    }
  }
}
