/// Persists and resolves opaque media blobs.
///
/// `MediaStorage` is the **only** abstraction in the codebase that knows the
/// difference between a file on disk and a remote object. Domain code receives
/// `MediaRef`; widgets receive `MediaRef` and ask `MediaStorage.resolveUri` to
/// turn the opaque [MediaRef.storageKey] into a URI Flutter can render
/// (`file://...` or `https://...`).
///
/// Phase 3 implementation: `LocalFileMediaStorage` (writes under the app
/// documents directory). Phase 4: `CloudMediaStorage` (signed URLs over HTTP).
/// Swapping is a one-line override in `main.dart`; no other call site changes.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.3.
abstract class MediaStorage {
  /// Persist [bytes] under [key]. Implementations may choose whether [key] is
  /// authoritative (caller-supplied) or whether the impl rewrites it; the
  /// returned String is always the canonical key the caller should store.
  ///
  /// [key] is expected to be base-scoped and content-addressable, e.g.
  /// `<baseId>/<uuid>.<ext>`. Callers must never pass an absolute path.
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  });

  /// Turn a previously-stored [key] into a URI a Flutter widget can render.
  /// Local impl returns `file://...`; cloud impl returns `https://...`.
  Future<String> resolveUri(String key);

  /// Best-effort delete; no-op if the underlying object is already gone.
  Future<void> delete(String key);
}
