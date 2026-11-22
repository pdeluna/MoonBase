import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/toggle_reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/watch_reactions.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/controllers/reaction_controller.dart';

const _m1 = ReactionTarget(kind: ReactionTargetKind.message, id: 'm1');

/// Feed is pushed manually; writes block on [gate] and answer from [script]
/// (a `Failure` ⇒ `Left`, otherwise `Right`).
class _Repo implements ReactionRepository {
  final StreamController<ReactionFeed> feed =
      StreamController<ReactionFeed>.broadcast();
  final List<Object?> script = <Object?>[];
  final List<String> calls = <String>[];
  Completer<void>? gate;

  Future<Either<Failure, void>> _answer(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    final next = script.isEmpty ? null : script.removeAt(0);
    if (next is Failure) return Left(next);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> react({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
    required ReactionKind kind,
  }) =>
      _answer('react:${target.id}:${kind.name}');

  @override
  Future<Either<Failure, void>> unreact({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
  }) =>
      _answer('unreact:${target.id}');

  @override
  Stream<ReactionFeed> watchFor({
    required BaseId baseId,
    required ReactionTargetKind targetKind,
  }) =>
      feed.stream;
}

Reaction _r(String uid, ReactionKind kind, {String targetId = 'm1'}) {
  final t = ReactionTarget(kind: ReactionTargetKind.message, id: targetId);
  return Reaction(
    id: Reaction.idFor(t, uid.uid),
    target: t,
    userId: uid.uid,
    kind: kind,
    createdAt: DateTime.utc(2026, 9, 27),
  );
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late _Repo repo;
  late ReactionController c;

  setUp(() async {
    repo = _Repo();
    c = ReactionController(ToggleReaction(repo), WatchReactions(repo));
    await c.load('b1');
    repo.feed.add(ReactionFeed(
      reactions: [_r('a', ReactionKind.heart)],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
  });

  tearDown(() => repo.feed.close());

  test('groupFor derives from the feed when nothing is in flight', () {
    final g = c.state.groupFor('m1', 'me'.uid);
    expect(g.counts, {ReactionKind.heart: 1});
    expect(g.mine, isNull);
    expect(c.state.groupFor('other', 'me'.uid), ReactionGroup.empty);
  });

  test(
      'toggle applies the projection immediately, calls the use case with '
      'current, and keeps the projection until the feed catches up', () async {
    repo.gate = Completer<void>();
    final pending = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.heart,
    );
    await _tick();

    // Optimistic: heart count went 1 → 2, mine == heart, before any Right.
    final g = c.state.groupFor('m1', 'me'.uid);
    expect(g.counts, {ReactionKind.heart: 2});
    expect(g.mine, ReactionKind.heart);
    expect(repo.calls, ['react:m1:heart']);

    repo.gate!.complete();
    await pending;
    // Still projected — feed has not confirmed yet.
    expect(c.state.optimistic.containsKey('m1'), isTrue);

    repo.feed.add(ReactionFeed(
      reactions: [_r('a', ReactionKind.heart), _r('me', ReactionKind.heart)],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
    expect(c.state.optimistic, isEmpty);
    expect(c.state.groupFor('m1', 'me'.uid).counts, {ReactionKind.heart: 2});
    expect(c.state.lastFailure, isNull);
  });

  test('same kind again → unreact (toggle off) with current passed through',
      () async {
    repo.feed.add(ReactionFeed(
      reactions: [_r('me', ReactionKind.fire)],
      freshness: ReactionFreshness.live,
    ));
    await _tick();

    await c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.fire,
    );

    expect(repo.calls, ['unreact:m1']);
    expect(c.state.groupFor('m1', 'me'.uid), ReactionGroup.empty);
  });

  test('Left rolls the projection back and raises a failure event', () async {
    repo.script.add(const NetworkFailure('offline'));

    await c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.wow,
    );

    expect(c.state.optimistic, isEmpty);
    final g = c.state.groupFor('m1', 'me'.uid);
    expect(g.counts, {ReactionKind.heart: 1});
    expect(g.mine, isNull);
    expect(c.state.lastFailure, isNotNull);
    expect(c.state.lastFailure!.target, _m1);
    expect(c.state.lastFailure!.failure.message, 'offline');
  });

  test('a second tap on the same target while one is in flight is ignored',
      () async {
    repo.gate = Completer<void>();
    final first = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.heart,
    );
    await c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.fire,
    );
    expect(repo.calls, ['react:m1:heart']);
    repo.gate!.complete();
    await first;
  });

  test(
      'projections on other targets survive a feed emission while theirs '
      'is in flight', () async {
    repo.gate = Completer<void>();
    final inflight = c.toggle(
      baseId: 'b1',
      target: const ReactionTarget(kind: ReactionTargetKind.message, id: 'm2'),
      userId: 'me',
      kind: ReactionKind.like,
    );
    await _tick();
    repo.feed.add(ReactionFeed(
      reactions: [_r('a', ReactionKind.heart)],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
    expect(c.state.optimistic.keys, ['m2']);
    repo.gate!.complete();
    await inflight;
  });

  test(
      'stream error (e.g. index not ready) → feed error, groupFor empty, '
      'no throw', () async {
    repo.feed.addError(const UnknownFailure('index building'));
    await _tick();
    expect(c.state.feed, isA<AsyncError<ReactionFeed>>());
    expect(c.state.groupFor('m1', 'me'.uid), ReactionGroup.empty);
  });

  test('load on a new base clears projections and resubscribes', () async {
    repo.gate = Completer<void>();
    final t = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.sad,
    );
    await _tick();
    expect(c.state.optimistic, isNotEmpty);
    await c.load('b2');
    expect(c.state.optimistic, isEmpty);
    expect(c.state.feed.isLoading, isTrue);
    repo.gate!.complete();
    await t;
  });

  test(
      'a confirming snapshot during the write drops the projection so '
      'concurrent reactions in that snapshot show', () async {
    repo.gate = Completer<void>();
    final pending = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.heart,
    );
    await _tick();

    repo.feed.add(ReactionFeed(
      reactions: [
        _r('a', ReactionKind.heart),
        _r('bob', ReactionKind.laugh),
        _r('me', ReactionKind.heart),
      ],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
    // Still in flight: the projection hides Bob until the write settles.
    expect(
      c.state.groupFor('m1', 'me'.uid).counts.containsKey(ReactionKind.laugh),
      isFalse,
    );

    repo.gate!.complete();
    await pending;

    expect(c.state.optimistic, isEmpty);
    final g = c.state.groupFor('m1', 'me'.uid);
    expect(g.counts, {ReactionKind.heart: 2, ReactionKind.laugh: 1});
    expect(g.mine, ReactionKind.heart);
  });

  test('a snapshot that does not yet include the write keeps the projection',
      () async {
    repo.gate = Completer<void>();
    final pending = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.wow,
    );
    await _tick();
    repo.feed.add(ReactionFeed(
      reactions: [
        _r('a', ReactionKind.heart),
        _r('bob', ReactionKind.laugh),
      ],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
    repo.gate!.complete();
    await pending;

    expect(c.state.optimistic.containsKey('m1'), isTrue);
    final hidden = c.state.groupFor('m1', 'me'.uid);
    expect(hidden.mine, ReactionKind.wow);
    expect(hidden.counts.containsKey(ReactionKind.laugh), isFalse);

    repo.feed.add(ReactionFeed(
      reactions: [
        _r('a', ReactionKind.heart),
        _r('bob', ReactionKind.laugh),
        _r('me', ReactionKind.wow),
      ],
      freshness: ReactionFreshness.live,
    ));
    await _tick();
    expect(c.state.optimistic, isEmpty);
    final shown = c.state.groupFor('m1', 'me'.uid);
    expect(shown.mine, ReactionKind.wow);
    expect(shown.counts[ReactionKind.laugh], 1);
  });

  test('a failure that lands after load() does not alert the new base',
      () async {
    repo.gate = Completer<void>();
    repo.script.add(const NetworkFailure('offline'));
    final t = c.toggle(
      baseId: 'b1',
      target: _m1,
      userId: 'me',
      kind: ReactionKind.sad,
    );
    await _tick();
    await c.load('b2');
    repo.gate!.complete();
    await t;
    expect(c.state.lastFailure, isNull);
    expect(c.state.optimistic, isEmpty);
  });
}
