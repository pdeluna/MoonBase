import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Phase 4 placeholder for a cloud-backed `MediaStorage`.
///
/// Intentionally **unimplemented** in Phase 3: the only purpose of shipping
/// this file now is to (a) reserve the file location predicted by the DoD
/// scaffold, and (b) make the eventual swap a contained change — one new
/// file (the concrete impl) + a one-line override in `main.dart`.
///
/// The Phase 4 implementation will:
///
/// - `putBytes`: PUT to a signed URL obtained from the backend, with
///   resumable uploads for video, and update [MediaRef.syncStatus] from
///   `uploading` → `synced` once acknowledged.
/// - `resolveUri`: return a short-lived signed download URL (or a CDN URL
///   for hot objects), so `Image.network` and `VideoPlayerController.network`
///   can render directly.
/// - `delete`: issue a DELETE against the object key and let the backend
///   tombstone it.
///
/// Subclassing instead of `implements MediaStorage` lets the cloud impl
/// extend this base if it grows shared concerns (signing, retry, telemetry).
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.5.
abstract class RemoteMediaStorage implements MediaStorage {
  const RemoteMediaStorage();
}
