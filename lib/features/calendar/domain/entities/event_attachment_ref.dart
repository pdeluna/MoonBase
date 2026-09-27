/// **Reserved extension point — nothing writes or reads this yet.**
///
/// Future member documents / pictures attached to a calendar event. Kept in
/// the calendar domain (not `MediaRef`) because event attachments will cover
/// documents as well as images, and the media feature's `MediaRef` is scoped
/// to chat-style image/video payloads.
///
/// When attachments ship (FIRESTORE_UPDATE_TRIGGERS #20): the event doc gains
/// an additive `attachmentPaths: string[]` field (rules `hasOnly` +
/// per-entry path match), a Storage path family under `bases/{baseId}/…`, and
/// `CalendarEventModel` starts mapping this list. No `schemaVersion` bump.
class EventAttachmentRef {
  const EventAttachmentRef({
    required this.storageKey,
    required this.kind,
    this.displayName,
  });

  /// Storage object path (never a download URL — same posture as `mediaPaths`).
  final String storageKey;
  final EventAttachmentKind kind;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAttachmentRef &&
          other.storageKey == storageKey &&
          other.kind == kind &&
          other.displayName == displayName);

  @override
  int get hashCode => Object.hash(storageKey, kind, displayName);
}

enum EventAttachmentKind { picture, document }
