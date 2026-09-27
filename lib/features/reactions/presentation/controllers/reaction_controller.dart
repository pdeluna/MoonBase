import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/toggle_reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/watch_reactions.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/providers/reaction_providers.dart';

/// One-shot signal that a toggle was rolled back; [seq] distinguishes
/// consecutive failures for `ref.listen`.
class ReactionFailureEvent {
  const ReactionFailureEvent({
    required this.seq,
    required this.target,
    required this.failure,
  });

  final int seq;
  final ReactionTarget target;
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      other is ReactionFailureEvent && other.seq == seq;

  @override
  int get hashCode => seq.hashCode;
}

class ReactionState {
  const ReactionState({
    this.feed = const AsyncValue<ReactionFeed>.loading(),
    this.optimistic = const <String, ReactionGroup>{},
    this.lastFailure,
  });

  final AsyncValue<ReactionFeed> feed;

  /// Per-target projection shown while a toggle is in flight (blueprint
  /// §2.3 optimistic UI). Keyed by target id; cleared by the next feed
  /// emission once the write has settled, or immediately on rollback.
  final Map<String, ReactionGroup> optimistic;

  final ReactionFailureEvent? lastFailure;

  ReactionState copyWith({
    AsyncValue<ReactionFeed>? feed,
    Map<String, ReactionGroup>? optimistic,
    ReactionFailureEvent? lastFailure,
  }) =>
      ReactionState(
        feed: feed ?? this.feed,
        optimistic: optimistic ?? this.optimistic,
        lastFailure: lastFailure ?? this.lastFailure,
      );

  /// Chip-row model for [targetId]: the optimistic projection if one is
  /// pending, else grouped from the live feed (empty when the feed is
  /// loading or errored — e.g. index not yet Enabled — so the screen still
  /// renders, just without chips).
  ReactionGroup groupFor(String targetId, UserId? me) {
    final override = optimistic[targetId];
    if (override != null) return override;
    final feed = this.feed.valueOrNull;
    if (feed == null) return ReactionGroup.empty;
    return ReactionGroup.from(
      feed.reactions.where((r) => r.target.id == targetId),
      me,
    );
  }
}

/// Single reactions listener per screen + optimistic toggle with rollback.
class ReactionController extends StateNotifier<ReactionState> {
  ReactionController(this._toggle, this._watch) : super(const ReactionState());

  final ToggleReaction _toggle;
  final WatchReactions _watch;

  StreamSubscription<ReactionFeed>? _sub;
  final Set<String> _inFlight = <String>{};
  int _failureSeq = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> load(
    String baseId, {
    ReactionTargetKind targetKind = ReactionTargetKind.message,
  }) async {
    _sub?.cancel();
    state = state.copyWith(
      feed: const AsyncValue<ReactionFeed>.loading(),
      optimistic: const <String, ReactionGroup>{},
    );
    _sub = _watch(baseId.bid, targetKind).listen(
      (feed) {
        if (!mounted) return;
        // Settled toggles are now reflected by the feed — drop their
        // projections; keep the ones still in flight.
        final keep = <String, ReactionGroup>{
          for (final e in state.optimistic.entries)
            if (_inFlight.contains(e.key)) e.key: e.value,
        };
        state = state.copyWith(feed: AsyncValue.data(feed), optimistic: keep);
      },
      onError: (Object error, StackTrace st) {
        if (!mounted) return;
        developer.log('ReactionController: stream error - $error');
        state = state.copyWith(feed: AsyncValue.error(error, st));
      },
    );
  }

  /// Apply the projected chip row at once, run the use case, roll back on
  /// `Left`. Never throws. A second tap on the same target while one is in
  /// flight is ignored (keeps the projection coherent).
  Future<void> toggle({
    required String baseId,
    required ReactionTarget target,
    required String userId,
    required ReactionKind kind,
  }) async {
    if (!_inFlight.add(target.id)) return;
    final me = userId.uid;
    final before = state.groupFor(target.id, me);
    final projected = before.applyToggle(kind);
    state = state.copyWith(
      optimistic: {...state.optimistic, target.id: projected},
    );

    final res = await _toggle(ToggleReactionParams(
      baseId: baseId.bid,
      target: target,
      userId: me,
      kind: kind,
      current: before.mine,
    ));
    _inFlight.remove(target.id);
    if (!mounted) return;

    res.match(
      (failure) {
        developer.log('ReactionController: toggle failed - ${failure.message}');
        final rolledBack = Map<String, ReactionGroup>.from(state.optimistic)
          ..remove(target.id);
        state = state.copyWith(
          optimistic: rolledBack,
          lastFailure: ReactionFailureEvent(
            seq: ++_failureSeq,
            target: target,
            failure: failure,
          ),
        );
      },
      (_) {
        // Keep the projection until the feed catches up (next emission
        // drops it because the target is no longer in flight).
      },
    );
  }
}

final reactionControllerProvider =
    StateNotifierProvider<ReactionController, ReactionState>((ref) {
  return ReactionController(
    ref.read(toggleReactionUseCaseProvider),
    ref.read(watchReactionsUseCaseProvider),
  );
});
