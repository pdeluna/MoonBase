import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';

/// Per-target roll-up for a chip row: counts by kind (enum order, zero
/// counts omitted) and which kind, if any, `me` cast.
@immutable
class ReactionGroup {
  const ReactionGroup({required this.counts, required this.mine});

  /// Reactions are already scoped to one target by the caller. Any
  /// duplicate `(user, target)` pairs (should not exist — deterministic id)
  /// are collapsed to the newest so a stale cache row can never double count.
  factory ReactionGroup.from(Iterable<Reaction> reactions, UserId? me) {
    final newestByUser = <UserId, Reaction>{};
    for (final r in reactions) {
      final prev = newestByUser[r.userId];
      if (prev == null || r.createdAt.isAfter(prev.createdAt)) {
        newestByUser[r.userId] = r;
      }
    }
    final counts = <ReactionKind, int>{};
    ReactionKind? mine;
    for (final r in newestByUser.values) {
      counts[r.kind] = (counts[r.kind] ?? 0) + 1;
      if (me != null && r.userId == me) mine = r.kind;
    }
    final ordered = <ReactionKind, int>{
      for (final k in ReactionKind.values)
        if ((counts[k] ?? 0) > 0) k: counts[k]!,
    };
    return ReactionGroup(counts: Map.unmodifiable(ordered), mine: mine);
  }

  static const ReactionGroup empty =
      ReactionGroup(counts: <ReactionKind, int>{}, mine: null);

  /// Kind → count, iteration order == [ReactionKind.values] order.
  final Map<ReactionKind, int> counts;

  /// The current user's reaction on this target, if any.
  final ReactionKind? mine;

  bool get isEmpty => counts.isEmpty;
  int get total => counts.values.fold(0, (a, b) => a + b);

  /// Pure local projection of "what the row looks like after I toggle
  /// [kind]" — used for optimistic UI; the server result replaces it.
  ReactionGroup applyToggle(ReactionKind kind) {
    final next = Map<ReactionKind, int>.from(counts);
    void dec(ReactionKind k) {
      final v = (next[k] ?? 0) - 1;
      if (v <= 0) {
        next.remove(k);
      } else {
        next[k] = v;
      }
    }

    if (mine == kind) {
      dec(kind);
      return ReactionGroup(counts: _ordered(next), mine: null);
    }
    if (mine != null) dec(mine!);
    next[kind] = (next[kind] ?? 0) + 1;
    return ReactionGroup(counts: _ordered(next), mine: kind);
  }

  static Map<ReactionKind, int> _ordered(Map<ReactionKind, int> m) =>
      Map.unmodifiable(<ReactionKind, int>{
        for (final k in ReactionKind.values)
          if ((m[k] ?? 0) > 0) k: m[k]!,
      });

  @override
  bool operator ==(Object other) =>
      other is ReactionGroup &&
      other.mine == mine &&
      mapEquals(other.counts, counts);

  @override
  int get hashCode => Object.hash(
        mine,
        Object.hashAll(counts.entries.map((e) => Object.hash(e.key, e.value))),
      );

  @override
  String toString() => 'ReactionGroup(counts: $counts, mine: $mine)';
}
