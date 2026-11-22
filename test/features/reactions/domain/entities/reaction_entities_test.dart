import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

const _target = ReactionTarget(kind: ReactionTargetKind.message, id: 'm1');

Reaction _r(String uid, ReactionKind kind, {int minute = 0}) => Reaction(
      id: Reaction.idFor(_target, uid.uid),
      target: _target,
      userId: uid.uid,
      kind: kind,
      createdAt: DateTime.utc(2026, 9, 27, 12, minute),
    );

void main() {
  group('ReactionKind / ReactionTargetKind', () {
    test('the six locked kinds, in order, mirror rules isValidReactionKind',
        () {
      expect(
        ReactionKind.values.map((k) => k.name).toList(),
        ['like', 'heart', 'laugh', 'wow', 'sad', 'fire'],
      );
    });

    test('tryParse accepts wire names and rejects unknown / non-string', () {
      expect(ReactionKind.tryParse('fire'), ReactionKind.fire);
      expect(ReactionKind.tryParse('thumbsdown'), isNull);
      expect(ReactionKind.tryParse(3), isNull);
      expect(ReactionTargetKind.tryParse('story'), ReactionTargetKind.story);
      expect(ReactionTargetKind.tryParse('tweet'), isNull);
    });

    test('only message has shipped (mirrors rules isShippedReactionTargetKind)',
        () {
      expect(ReactionTargetKind.shipped, {ReactionTargetKind.message});
      expect(ReactionTargetKind.message.isShipped, isTrue);
      for (final k in ReactionTargetKind.values
          .where((k) => k != ReactionTargetKind.message)) {
        expect(k.isShipped, isFalse, reason: k.name);
      }
    });
  });

  test('Reaction.idFor is targetKind:targetId:uid', () {
    expect(Reaction.idFor(_target, 'bob'.uid).value, 'message:m1:bob');
  });

  group('ReactionGroup.from', () {
    test('counts by kind in enum order, zero counts omitted, mine detected',
        () {
      final g = ReactionGroup.from(
        [
          _r('a', ReactionKind.fire),
          _r('b', ReactionKind.heart),
          _r('c', ReactionKind.fire),
          _r('me', ReactionKind.like),
        ],
        'me'.uid,
      );

      expect(g.counts.keys.toList(),
          [ReactionKind.like, ReactionKind.heart, ReactionKind.fire]);
      expect(g.counts[ReactionKind.fire], 2);
      expect(g.counts[ReactionKind.heart], 1);
      expect(g.mine, ReactionKind.like);
      expect(g.total, 4);
      expect(g.isEmpty, isFalse);
    });

    test(
        'duplicate rows for one user collapse to the newest (no double '
        'count)', () {
      final g = ReactionGroup.from(
        [
          _r('a', ReactionKind.heart, minute: 1),
          _r('a', ReactionKind.fire, minute: 2),
        ],
        null,
      );
      expect(g.counts, {ReactionKind.fire: 1});
      expect(g.mine, isNull);
    });

    test('empty input is ReactionGroup.empty', () {
      expect(ReactionGroup.from(const [], 'me'.uid), ReactionGroup.empty);
    });
  });

  group('ReactionGroup.applyToggle (optimistic projection)', () {
    final base = ReactionGroup.from(
      [_r('a', ReactionKind.heart), _r('me', ReactionKind.heart)],
      'me'.uid,
    );

    test('same kind toggles off', () {
      final next = base.applyToggle(ReactionKind.heart);
      expect(next.counts, {ReactionKind.heart: 1});
      expect(next.mine, isNull);
    });

    test('different kind replaces (count moves, total unchanged)', () {
      final next = base.applyToggle(ReactionKind.fire);
      expect(next.counts, {ReactionKind.heart: 1, ReactionKind.fire: 1});
      expect(next.mine, ReactionKind.fire);
      expect(next.total, base.total);
    });

    test('no prior reaction adds one', () {
      final next = ReactionGroup.empty.applyToggle(ReactionKind.wow);
      expect(next.counts, {ReactionKind.wow: 1});
      expect(next.mine, ReactionKind.wow);
    });

    test('result is value-equal to a from() of the same rows', () {
      final viaToggle = base.applyToggle(ReactionKind.fire);
      final viaRows = ReactionGroup.from(
        [_r('a', ReactionKind.heart), _r('me', ReactionKind.fire)],
        'me'.uid,
      );
      expect(viaToggle, viaRows);
    });
  });
}
