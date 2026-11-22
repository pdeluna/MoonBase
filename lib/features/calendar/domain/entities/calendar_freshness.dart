/// Whether the calendar feed was served from the local Firestore cache or
/// from the server.
///
/// One value for the whole list — snapshot metadata is not per-event.
/// Mirrors `ChatFreshness` deliberately instead of reusing it: one enum per
/// feature keeps chat and calendar independent (both are cache-vs-live, R5).
enum CalendarFreshness {
  /// Last snapshot was cache (`SnapshotMetadata.isFromCache == true`).
  cached,

  /// Last snapshot was server (`SnapshotMetadata.isFromCache == false`).
  live,
}
