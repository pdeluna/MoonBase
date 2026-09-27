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

/// What a toggle is waiting on. [expectedMine] is the projected kind for
/// [userId] (`null` = toggled off). The stream is the source of truth once
/// a snapshot already shows that outcome.
class _ToggleInFlight {
  const _ToggleInFlight({required this.userId, required this.expectedMine});

  final UserId userId;
  final ReactionKind? expectedMine;
}

/// Newest kind [userId] has on [targetId] in [feed], or null.
ReactionKind? _kindForUser(ReactionFeed feed, String targetId, UserId userId) {
  ReactionKind? kind;
  DateTime? newest;
  for (final r in feed.reactions) {
    if (r.target.id != targetId || r.userId != userId) continue;
    if (newest == null || r.createdAt.isAfter(newest)) {
      newest = r.createdAt;
      kind = r.kind;
    }
  }
  return kind;
}

/// Single reactions listener per screen + optimistic toggle with rollback.
///
/// [load] takes any [ReactionTargetKind] so chat, stories, and comments
/// share this controller; only one surface is subscribed at a time (a new
/// `load` cancels the previous listener).
class ReactionController extends StateNotifier<ReactionState> {
  ReactionController(this._toggle, this._watch) : super(const ReactionState());

  final ToggleReaction _toggle;
  final WatchReactions _watch;

  StreamSubscription<ReactionFeed>? _sub;
  final Map<String, _ToggleInFlight> _inFlight = {};

  /// Target ids whose latest in-flight snapshot already shows the projected
  /// kind. Firestore often delivers that snapshot before `set()`/`delete()`
  /// completes; dropping the projection then lets concurrent reactions in
  /// the same snapshot through.
  final Set<String> _reflected = <String>{};
  int _failureSeq = 0;
  int _epoch = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> load(
    String baseId, {
    ReactionTargetKind targetKind = ReactionTargetKind.message,
  }) async {
    final epoch = ++_epoch;
    _sub?.cancel();
    _inFlight.clear();
    _reflected.clear();
    state = state.copyWith(
      feed: const AsyncValue<ReactionFeed>.loading(),
      optimistic: const <String, ReactionGroup>{},
    );
    _sub = _watch(baseId.bid, targetKind).listen(
      (feed) {
        if (!mounted || epoch != _epoch) return;
        for (final e in _inFlight.entries) {
          final actual = _kindForUser(feed, e.key, e.value.userId);
          if (actual == e.value.expectedMine) {
            _reflected.add(e.key);
          } else {
            _reflected.remove(e.key);
          }
        }
        // Settled toggles are now reflected by the feed — drop their
        // projections; keep the ones still in flight.
        final keep = <String, ReactionGroup>{
          for (final e in state.optimistic.entries)
            if (_inFlight.containsKey(e.key)) e.key: e.value,
        };
        state = state.copyWith(feed: AsyncValue.data(feed), optimistic: keep);
      },
      onError: (Object error, StackTrace st) {
        if (!mounted || epoch != _epoch) return;
        developer.log('ReactionController: stream error - $error');
        state = state.copyWith(feed: AsyncValue.error(error, st));
      },
    );
  }

  /// Apply the projected chip row at once, run the use case, roll back on
  /// `Left`. Never throws. A second tap on the same target while one is in
  /// flight is ignored (keeps the projection coherent). A result that lands
  /// after [load] switched bases is ignored.
  Future<void> toggle({
    required String baseId,
    required ReactionTarget target,
    required String userId,
    required ReactionKind kind,
  }) async {
    if (_inFlight.containsKey(target.id)) return;
    final epoch = _epoch;
    final me = userId.uid;
    final before = state.groupFor(target.id, me);
    final projected = before.applyToggle(kind);
    _inFlight[target.id] = _ToggleInFlight(
      userId: me,
      expectedMine: projected.mine,
    );
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
    if (!mounted || epoch != _epoch) return;
    _inFlight.remove(target.id);
    final reflected = _reflected.remove(target.id);

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
        if (!reflected) return;
        // The feed already shows this outcome (and any concurrent
        // reactions that landed in the same snapshot).
        final next = Map<String, ReactionGroup>.from(state.optimistic)
          ..remove(target.id);
        state = state.copyWith(optimistic: next);
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
