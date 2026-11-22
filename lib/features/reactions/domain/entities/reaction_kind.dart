/// The locked MVP reaction set (Phase 3 blueprint §1; plan §10).
///
/// **Single source of truth for kind strings.** `name` is the wire value
/// written to Firestore; `firestore.rules` `isValidReactionKind` mirrors
/// this list and the emulator suite pins all six — change both together.
enum ReactionKind {
  like,
  heart,
  laugh,
  wow,
  sad,
  fire;

  /// Parses a wire value; null for anything outside the locked set so a
  /// future kind written by a newer client is dropped, not crashed on.
  static ReactionKind? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final k in ReactionKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}
