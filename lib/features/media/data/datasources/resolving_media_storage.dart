import 'dart:io';

import 'package:moonbase_skeleton/features/media/data/datasources/local_file_media_storage.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Facade over local staging storage + cloud storage for widget resolve paths.
///
/// Wired as [mediaStorageProvider]:
/// - [putBytes] / [delete] → local only (picker staging + unstage).
/// - [resolveUri] routes by key shape:
///   - local `<baseId>/<uuid>.<ext>` → [LocalFileMediaStorage]
///   - cloud `bases/{baseId}/media/{uuid}.jpg` → local-first probe for a
///     renderable staged sibling, else cloud [MediaStorage.resolveUri]
///     (`getDownloadURL`).
///
/// Sender local-first: after upload the message carries only the cloud key,
/// but the staged file is still on disk under the same uuid. Preferring that
/// file avoids a re-download on the sending device. Only renderable extensions
/// are preferred (jpg/jpeg/png/webp/gif) — HEIC/unknown fall through to the
/// cloud JPEG (**HEIC / iOS unverified**).
class ResolvingMediaStorage implements MediaStorage {
  ResolvingMediaStorage({
    required LocalFileMediaStorage local,
    required MediaStorage cloud,
  })  : _local = local,
        _cloud = cloud;

  final LocalFileMediaStorage _local;
  final MediaStorage _cloud;

  /// Extensions Flutter can typically decode without platform codecs.
  static const _renderableExts = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) =>
      _local.putBytes(key: key, bytes: bytes, mimeType: mimeType);

  @override
  Future<void> delete(String key) => _local.delete(key);

  @override
  Future<String> resolveUri(String key) async {
    final uuid = mediaUuidFromStoragePath(key);
    if (uuid != null) {
      final localUri = await _probeLocalRenderable(cloudPath: key, uuid: uuid);
      if (localUri != null) return localUri;
      return _cloud.resolveUri(key);
    }
    return _local.resolveUri(key);
  }

  /// Looks under `media/{baseId}/` for `{uuid}.{renderableExt}`.
  Future<String?> _probeLocalRenderable({
    required String cloudPath,
    required String uuid,
  }) async {
    final segments = cloudPath.split('/');
    if (segments.length != 4) return null;
    final baseId = segments[1];
    if (baseId.isEmpty) return null;

    final dir = Directory('${_local.docsDir.path}/media/$baseId');
    if (!await dir.exists()) return null;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final stem = name.substring(0, dot);
      final ext = name.substring(dot + 1).toLowerCase();
      if (stem != uuid || !_renderableExts.contains(ext)) continue;
      if (await entity.exists()) return entity.uri.toString();
    }
    return null;
  }
}
