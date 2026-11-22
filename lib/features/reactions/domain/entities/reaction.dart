import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// One user's reaction to one target. Invariant: **one per `(user, target)`**
/// — guaranteed by the deterministic id ([idFor]) rather than by a query or
/// transaction. Re-reacting with another kind replaces; the same kind again
/// removes (see `ToggleReaction`).
@immutable
class Reaction {
  const Reaction({
    required this.id,
    required this.target,
    required this.userId,
    required this.kind,
    required this.createdAt,
  });

  /// Builds the canonical id `{targetKind}:{targetId}:{uid}`. This is the
  /// **only** place the shape is written in Dart; `firestore.rules`
  /// recomputes it from the body and denies any mismatch.
  static ReactionId idFor(ReactionTarget target, UserId userId) =>
      ReactionId('${target.kind.name}:${target.id}:${userId.value}');

  final ReactionId id;
  final ReactionTarget target;
  final UserId userId;
  final ReactionKind kind;
  final DateTime createdAt;

  Reaction copyWith({ReactionKind? kind, DateTime? createdAt}) => Reaction(
        id: id,
        target: target,
        userId: userId,
        kind: kind ?? this.kind,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Reaction &&
      other.id == id &&
      other.target == target &&
      other.userId == userId &&
      other.kind == kind &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, target, userId, kind, createdAt);

  @override
  String toString() =>
      'Reaction(${id.value}, kind: ${kind.name}, at: $createdAt)';
}
