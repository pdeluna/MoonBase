import 'package:flutter/foundation.dart';

/// What a reaction is attached to.
///
/// Every kind is reserved in the enum so the id shape and the codec never
/// change when a new surface ships; only [shipped] grows. Rules mirror
/// [shipped] in `isShippedReactionTargetKind` — flip both together
/// (trigger #17).
enum ReactionTargetKind {
  message,
  story,
  comment,
  post,
  event;

  /// Kinds whose target collection exists and is ruled. Reacting to any
  /// other kind is a `ValidationFailure` in Dart and a denial in rules.
  static const Set<ReactionTargetKind> shipped = <ReactionTargetKind>{
    ReactionTargetKind.message,
  };

  bool get isShipped => shipped.contains(this);

  static ReactionTargetKind? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final k in ReactionTargetKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

/// `(kind, id)` of the document a reaction points at. [id] is the target's
/// doc id under the same base (a `MessageId.value` for `message`).
@immutable
class ReactionTarget {
  const ReactionTarget({required this.kind, required this.id})
      : assert(id != '');

  final ReactionTargetKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ReactionTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'ReactionTarget(${kind.name}:$id)';
}
