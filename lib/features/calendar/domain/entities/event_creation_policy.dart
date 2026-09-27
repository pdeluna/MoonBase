/// Who may create events in a base's calendar.
///
/// Wire values (`'members'` / `'owner'`) live in the data codec and in
/// `firestore.rules` (`isValidEventCreation`); the default when the settings
/// doc is missing is [allMembers] — see `CalendarSettings.defaults`, the one
/// defaults constant (FIRESTORE_UPDATE_TRIGGERS #17).
///
/// The policy gates **creation only**. Editing / deleting an event is always
/// author-or-owner (`canModifyEvent`), regardless of this value (U-1).
enum EventCreationPolicy {
  allMembers,
  ownerOnly,
}
