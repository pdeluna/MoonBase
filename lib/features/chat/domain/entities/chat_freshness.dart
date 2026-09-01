/// Whether the chat feed was served from the local Firestore cache or from
/// the server.
///
/// One value for the whole list — snapshot metadata is not per-message.
/// Do not reuse [SyncStatus]; that is per-message outbox state.
enum ChatFreshness {
  /// Last snapshot was cache (`SnapshotMetadata.isFromCache == true`).
  cached,

  /// Last snapshot was server (`SnapshotMetadata.isFromCache == false`).
  live,
}
