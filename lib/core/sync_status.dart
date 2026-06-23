/// Tracks the upload state of a persisted entity that carries media or other
/// blobs the app may eventually replicate to a backend.
///
/// Phase 3 is local-only, so all writes are created with [synced]; the field
/// exists so a future Phase 4 outbox/sync service can replay records where
/// [syncStatus] is anything other than [synced] without a schema migration.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.2.1.
enum SyncStatus {
  /// Persisted locally; cloud not yet attempted.
  localOnly,

  /// Upload in progress.
  uploading,

  /// Local + cloud are in agreement (the only state used while local-only).
  synced,

  /// Last upload attempt failed; should be retried by the sync service.
  failed,
}
