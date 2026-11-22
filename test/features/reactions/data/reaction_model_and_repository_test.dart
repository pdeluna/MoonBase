import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source_impl.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_batch.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_model.dart';
import 'package:moonbase_skeleton/features/reactions/data/repositories/reaction_repository_impl.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

const _target = ReactionTarget(kind: ReactionTargetKind.message, id: 'm1');

/// Emits whatever the test pushes (batches or errors); writes throw
/// [writeError] when set.
class _ScriptedSource implements ReactionDataSource {
  final StreamController<ReactionBatch> ctrl =
      StreamController<ReactionBatch>();
  Object? writeError;
  final List<String> writes = <String>[];

  @override
  Future<void> react({
    required String baseId,
    required ReactionTarget target,
    required String uid,
    required ReactionKind kind,
  }) async {
    if (writeError != null) throw writeError!;
    writes.add('react:${Reaction.idFor(target, uid.uid).value}:${kind.name}');
  }

  @override
  Future<void> unreact({
    required String baseId,
    required ReactionTarget target,
    required String uid,
  }) async {
    if (writeError != null) throw writeError!;
    writes.add('unreact:${Reaction.idFor(target, uid.uid).value}');
  }

  @override
  Stream<ReactionBatch> watchFor({
    required String baseId,
    required ReactionTargetKind targetKind,
  }) =>
      ctrl.stream;
}

void main() {
  group('ReactionModel codec', () {
    test('toFirestore writes exactly the six ruled keys with schemaVersion 1',
        () {
      final m = ReactionModel(
        id: 'message:m1:bob',
        targetKind: ReactionTargetKind.message,
        targetId: 'm1',
        uid: 'bob',
        kind: ReactionKind.heart,
        createdAt: DateTime.utc(2026),
      );
      final doc = m.toFirestore();
      expect(doc.keys.toSet(), {
        'targetKind',
        'targetId',
        'uid',
        'kind',
        'createdAt',
        'schemaVersion',
      });
      expect(doc['targetKind'], 'message');
      expect(doc['targetId'], 'm1');
      expect(doc['uid'], 'bob');
      expect(doc['kind'], 'heart');
      expect(doc['schemaVersion'], 1);
      expect(doc['createdAt'], isA<FieldValue>());
    });

    test('fromFirestore round-trips and toEntity types the ids', () {
      final m = ReactionModel.fromFirestore('message:m1:bob', {
        'targetKind': 'message',
        'targetId': 'm1',
        'uid': 'bob',
        'kind': 'fire',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 27, 12)),
        'schemaVersion': 1,
      })!;
      final e = m.toEntity();
      expect(e.id, 'message:m1:bob'.rid);
      expect(e.target, _target);
      expect(e.userId, 'bob'.uid);
      expect(e.kind, ReactionKind.fire);
      expect(e.createdAt, DateTime.utc(2026, 9, 27, 12));
      expect(e.id, Reaction.idFor(e.target, e.userId));
    });

    test('pending serverTimestamp (null createdAt) stands in with now', () {
      final before = DateTime.now().toUtc();
      final m = ReactionModel.fromFirestore('message:m1:bob', {
        'targetKind': 'message',
        'targetId': 'm1',
        'uid': 'bob',
        'kind': 'like',
        'createdAt': null,
        'schemaVersion': 1,
      })!;
      expect(m.createdAt.isBefore(before), isFalse);
    });

    test('unknown kind / target kind / malformed body → null (dropped)', () {
      Map<String, dynamic> base() => {
            'targetKind': 'message',
            'targetId': 'm1',
            'uid': 'bob',
            'kind': 'heart',
            'createdAt': Timestamp.now(),
            'schemaVersion': 1,
          };
      expect(
          ReactionModel.fromFirestore('x', {...base(), 'kind': 'meh'}), isNull);
      expect(
          ReactionModel.fromFirestore('x', {...base(), 'targetKind': 'tweet'}),
          isNull);
      expect(ReactionModel.fromFirestore('x', {...base(), 'targetId': ''}),
          isNull);
      expect(ReactionModel.fromFirestore('x', {...base(), 'uid': 7}), isNull);
    });
  });

  group('ReactionRepositoryImpl', () {
    test(
        'react / unreact go through guardVoid: Right on success, typed Left '
        'on throw', () async {
      final src = _ScriptedSource();
      final repo = ReactionRepositoryImpl(source: src);

      final ok = await repo.react(
        baseId: 'b1'.bid,
        target: _target,
        userId: 'me'.uid,
        kind: ReactionKind.wow,
      );
      expect(ok.isRight, isTrue);
      expect(src.writes, ['react:message:m1:me:wow']);

      src.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      final bad = await repo.unreact(
          baseId: 'b1'.bid, target: _target, userId: 'me'.uid);
      expect(bad, isA<Left<Failure, void>>());
      expect((bad as Left<Failure, void>).value, isA<NetworkFailure>());

      src.writeError = StateError('not signed in');
      final denied = await repo.react(
        baseId: 'b1'.bid,
        target: _target,
        userId: 'me'.uid,
        kind: ReactionKind.wow,
      );
      expect((denied as Left<Failure, void>).value, isA<CacheFailure>());
    });

    test('watchFor maps batches to ReactionFeed with freshness', () async {
      final src = _ScriptedSource();
      final repo = ReactionRepositoryImpl(source: src);
      final events = <ReactionFeed>[];
      final sub = repo
          .watchFor(baseId: 'b1'.bid, targetKind: ReactionTargetKind.message)
          .listen(events.add);

      src.ctrl.add(ReactionBatch(
        reactions: [
          ReactionModel(
            id: 'message:m1:a',
            targetKind: ReactionTargetKind.message,
            targetId: 'm1',
            uid: 'a',
            kind: ReactionKind.sad,
            createdAt: DateTime.utc(2026),
          ),
        ],
        fromCache: true,
      ));
      src.ctrl.add(const ReactionBatch(reactions: [], fromCache: false));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events.first.freshness, ReactionFreshness.cached);
      expect(events.first.reactions.single.userId, 'a'.uid);
      expect(events.last.freshness, ReactionFreshness.live);
      await sub.cancel();
      await src.ctrl.close();
    });

    test(
        'failed-precondition on the stream (index not Enabled) surfaces as '
        'a typed Failure, not a raw FirebaseException', () async {
      final src = _ScriptedSource();
      final repo = ReactionRepositoryImpl(source: src);
      final errors = <Object>[];
      final sub = repo
          .watchFor(baseId: 'b1'.bid, targetKind: ReactionTargetKind.message)
          .listen((_) {}, onError: errors.add);

      src.ctrl.addError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'The query requires an index.',
      ));
      src.ctrl.addError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(2));
      expect(errors.first, isA<UnknownFailure>());
      expect((errors.first as Failure).message, kReactionsIndexNotReadyMessage);
      expect(errors.last, isA<NetworkFailure>());
      expect(errors.whereType<FirebaseException>(), isEmpty);
      await sub.cancel();
      await src.ctrl.close();
    });

    test(
        'with the in-memory source: react → replace → toggle off is one row '
        'then none', () async {
      final ds = InMemoryReactionDataSource();
      final repo = ReactionRepositoryImpl(source: ds);
      final feeds = <ReactionFeed>[];
      final sub = repo
          .watchFor(baseId: 'b1'.bid, targetKind: ReactionTargetKind.message)
          .listen(feeds.add);
      await Future<void>.delayed(Duration.zero);

      await repo.react(
          baseId: 'b1'.bid,
          target: _target,
          userId: 'me'.uid,
          kind: ReactionKind.heart);
      await repo.react(
          baseId: 'b1'.bid,
          target: _target,
          userId: 'me'.uid,
          kind: ReactionKind.fire);
      await Future<void>.delayed(Duration.zero);
      expect(feeds.last.reactions, hasLength(1));
      expect(feeds.last.reactions.single.kind, ReactionKind.fire);
      expect(feeds.last.reactions.single.id, 'message:m1:me'.rid);

      await repo.unreact(baseId: 'b1'.bid, target: _target, userId: 'me'.uid);
      await Future<void>.delayed(Duration.zero);
      expect(feeds.last.reactions, isEmpty);
      await sub.cancel();
    });
  });
}
