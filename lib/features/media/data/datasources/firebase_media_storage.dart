import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/media/data/datasources/remote_media_storage.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';

/// Compresses [bytes] to JPEG. Returns null when the codec cannot decode.
///
/// **HEIC:** not proven on our Android test device — verify on iOS build day.
/// Failure path is [MediaUnsupportedFailure] from [FirebaseMediaStorage.putBytes].
typedef JpegCompressFn = Future<Uint8List?> Function(
  Uint8List bytes, {
  required int quality,
  required int maxEdge,
});

/// Uploads JPEG bytes to a Storage object path with explicit content-type.
typedef StoragePutFn = Future<void> Function({
  required String path,
  required Uint8List bytes,
  required String contentType,
});

/// Resolves a Storage object [path] to a short-lived HTTPS download URL.
typedef StorageGetDownloadUrlFn = Future<String> Function(String path);

/// Dart-side await cap for [FirebaseMediaStorage.resolveUri] / getDownloadURL.
///
/// Ordered after `kFirebaseStorageMaxOperationRetry` (15s native retry budget)
/// on purpose — they bound different things (native retry vs Dart
/// `Future.timeout`) and **must not be set equal**. Native 15s is the expected
/// terminator; this 20s timeout is a backstop if the native layer never
/// returns. Either can legitimately be absent (this default is unused when
/// tests inject [FirebaseMediaStorage.resolveTimeout]; native caps are unused
/// when getDownloadURL is stubbed).
const Duration kFirebaseMediaResolveTimeout = Duration(seconds: 20);

/// Cloud [MediaStorage]: compress to JPEG ≤ 10 MB, then upload to Firebase Storage.
///
/// ## Pass-2 obligation (interface seam)
///
/// [putBytes] returns [Future] and **throws** typed [Failure]s (and may throw
/// Firebase/plugin errors). It does **not** return `Either`. Pass 2 send
/// orchestration **must** wrap every `putBytes` call in `guard(...)` (or
/// equivalent try → `Left(Failure)`). An unguarded call will throw raw and
/// crash the send flow.
///
/// ## Pass 3 — [resolveUri]
///
/// Returns `https://...` via [Reference.getDownloadURL]. Throws on invalid
/// keys / Firebase errors (same Future-throws convention as [putBytes]; the
/// port is not `Either`). Widgets map failures to a broken-image fallback.
///
/// In-flight / completed download-URL futures are memoized per Storage path for
/// the session so chat rebuilds share one `getDownloadURL` call. Failed
/// futures are evicted so a later retry can succeed. [resolveTimeout] (see
/// [kFirebaseMediaResolveTimeout]) is a Dart-side backstop if the native
/// layer never returns — not the expected terminator; that is
/// `kFirebaseStorageMaxOperationRetry` (15s native retry budget). The two
/// must not be set equal.
///
/// Download URLs carry rotating auth tokens — render caches **must** key on
/// the stable Storage path (`bases/{baseId}/media/{uuid}.jpg`), not the URL.
///
/// ## Scope
///
/// - [putBytes]: compress + upload.
/// - [resolveUri]: download URL for render.
/// - [delete] stays [UnimplementedError] permanently — Storage ADR denies
///   client deletes; not deferred to a later pass.
///
/// **HEIC / iOS:** upload + render unverified until iOS build day.
class FirebaseMediaStorage extends RemoteMediaStorage {
  FirebaseMediaStorage({
    FirebaseStorage? storage,
    JpegCompressFn? compressJpeg,
    StoragePutFn? putObject,
    StorageGetDownloadUrlFn? getDownloadUrl,
    this.maxBytes = MediaConstraints.imageMaxBytesDefault,
    this.maxEdge = 1920,
    this.initialQuality = 80,
    this.resolveTimeout = kFirebaseMediaResolveTimeout,
  })  : _compressJpeg = compressJpeg ?? _defaultCompressJpeg,
        // Defaults close over [storage] and only touch FirebaseStorage.instance
        // when invoked — so unit tests that stub put/get never need Firebase.
        _putObject = putObject ?? _defaultPutObject(storage),
        _getDownloadUrl = getDownloadUrl ?? _defaultGetDownloadUrl(storage);

  final JpegCompressFn _compressJpeg;
  final StoragePutFn _putObject;
  final StorageGetDownloadUrlFn _getDownloadUrl;

  /// Session memo of path → in-flight/completed download URL future.
  final Map<String, Future<String>> _downloadUrlByPath = {};

  /// Post-compression ceiling (matches `storage.rules` + [MediaConstraints]).
  final int maxBytes;

  /// Long-edge cap for `flutter_image_compress` (keeps aspect ratio).
  final int maxEdge;

  /// First quality attempt before the ladder.
  final int initialQuality;

  /// Dart-side await cap for [getDownloadURL] so a hung native RPC cannot
  /// leave tiles spinning. See [kFirebaseMediaResolveTimeout]. Ordered after
  /// `kFirebaseStorageMaxOperationRetry` on purpose — must not be set equal.
  final Duration resolveTimeout;

  static const _qualityLadder = [80, 70, 55, 40, 25];

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final cloudPath = cloudStoragePathFromKey(key);
    final source = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    final jpeg = await _compressToJpegUnderCap(source);
    await _putObject(
      path: cloudPath,
      bytes: jpeg,
      contentType: 'image/jpeg',
    );
    return cloudPath;
  }

  @override
  Future<String> resolveUri(String key) {
    final path = cloudStoragePathFromKey(key);
    final existing = _downloadUrlByPath[path];
    if (existing != null) return existing;

    final future = _resolveDownloadUrl(path);
    _downloadUrlByPath[path] = future;
    return future;
  }

  Future<String> _resolveDownloadUrl(String path) async {
    try {
      return await _getDownloadUrl(path).timeout(
        resolveTimeout,
        onTimeout: () => throw const NetworkFailure(
          'Timed out resolving media download URL.',
        ),
      );
    } catch (_) {
      // Evict so a later attempt (e.g. after auth settles) can retry.
      _downloadUrlByPath.remove(path);
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) {
    // Permanent: Storage rules deny client deletes (ADR). Admin/CF cleanup later.
    throw UnimplementedError(
      'FirebaseMediaStorage.delete is not supported; '
      'Storage ADR denies client deletes.',
    );
  }

  Future<Uint8List> _compressToJpegUnderCap(Uint8List source) async {
    final qualities = <int>[
      initialQuality,
      for (final q in _qualityLadder)
        if (q != initialQuality) q,
    ];

    Uint8List? last;
    for (final quality in qualities) {
      final compressed = await _compressJpeg(
        source,
        quality: quality,
        maxEdge: maxEdge,
      );
      if (compressed == null || compressed.isEmpty) {
        throw const MediaUnsupportedFailure(
          'Could not encode image as JPEG for upload.',
        );
      }
      last = compressed;
      if (compressed.length <= maxBytes) {
        return compressed;
      }
    }

    throw MediaTooLargeFailure(
      'Compressed image exceeds the ${maxBytes ~/ (1024 * 1024)} MB upload cap '
      '(${last?.length ?? 0} bytes).',
    );
  }
}

Future<Uint8List?> _defaultCompressJpeg(
  Uint8List bytes, {
  required int quality,
  required int maxEdge,
}) async {
  final out = await FlutterImageCompress.compressWithList(
    bytes,
    quality: quality,
    minWidth: maxEdge,
    minHeight: maxEdge,
    format: CompressFormat.jpeg,
  );
  if (out.isEmpty) return null;
  return Uint8List.fromList(out);
}

StoragePutFn _defaultPutObject(FirebaseStorage? storage) {
  return ({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // contentType is required: storage.rules match image/.* on metadata.
    await (storage ?? FirebaseStorage.instance).ref(path).putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
  };
}

StorageGetDownloadUrlFn _defaultGetDownloadUrl(FirebaseStorage? storage) {
  return (path) =>
      (storage ?? FirebaseStorage.instance).ref(path).getDownloadURL();
}
