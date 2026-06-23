import 'dart:async';
import 'dart:io';

import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// On-disk `MediaStorage` implementation, writing under the app documents
/// directory.
///
/// Layout:
///
/// ```
/// <docsDir>/
///   media/
///     <baseId>/
///       <uuid>.<ext>          // canonical storage key: "<baseId>/<uuid>.<ext>"
/// ```
///
/// Why content-addressable relative keys?
///
/// The docs directory path can change between app reinstalls (especially on
/// iOS where the container UUID is rolled), so persisted absolute paths
/// rapidly become stale. Storing only `<baseId>/<uuid>.<ext>` and resolving
/// it lazily on read keeps media references portable across reinstalls and
/// makes the Phase 4 cloud transition a single-line swap.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.5.
class LocalFileMediaStorage implements MediaStorage {
  LocalFileMediaStorage(this.docsDir);

  /// Root directory under which the `media/` subtree is created.
  /// Wire this with `getApplicationDocumentsDirectory()` in `main.dart`.
  final Directory docsDir;

  /// Root of all media on disk. Lazily created on first write.
  Directory get _mediaRoot => Directory('${docsDir.path}/media');

  File _fileForKey(String key) {
    if (key.startsWith('/') || key.contains('..')) {
      // Defensive: keys are content-addressable relative paths only. An
      // absolute path or path-traversal segment would either escape the media
      // root or shadow another key on disk.
      throw ArgumentError.value(key, 'key',
          'storageKey must be a base-scoped relative path like "<baseId>/<uuid>.<ext>"');
    }
    return File('${_mediaRoot.path}/$key');
  }

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final file = _fileForKey(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return key;
  }

  @override
  Future<String> resolveUri(String key) async {
    // Return a `file://` URI Flutter's Image.file / VideoPlayerController.file
    // can load. We intentionally do not check for existence here — that is the
    // widget's job (and avoids a per-tile stat).
    return _fileForKey(key).uri.toString();
  }

  @override
  Future<void> delete(String key) async {
    final file = _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
