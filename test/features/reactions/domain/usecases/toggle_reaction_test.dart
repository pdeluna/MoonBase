import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/toggle_reaction.dart';

class _MockRepo extends Mock implements ReactionRepository {}

const _target = ReactionTarget(kind: ReactionTargetKind.message, id: 'm1');

void main() {
  late _MockRepo repo;
  late ToggleReaction useCase;

  setUpAll(() {
    registerFallbackValue('b1'.bid);
    registerFallbackValue('u1'.uid);
    registerFallbackValue(_target);
    registerFallbackValue(ReactionKind.like);
  });

  setUp(() {
    repo = _MockRepo();
    useCase = ToggleReaction(repo);
    when(() => repo.react(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async => const Right(null));
    when(() => repo.unreact(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => const Right(null));
  });

  ToggleReactionParams params({
    required ReactionKind kind,
    ReactionKind? current,
    ReactionTarget target = _target,
  }) =>
      ToggleReactionParams(
        baseId: 'b1'.bid,
        target: target,
        userId: 'me'.uid,
        kind: kind,
        current: current,
      );

  test('no prior reaction → react, returns the kind', () async {
    final res = await useCase(params(kind: ReactionKind.heart));

    expect(res, const Right<Failure, ReactionKind?>(ReactionKind.heart));
    verify(() => repo.react(
          baseId: 'b1'.bid,
          target: _target,
          userId: 'me'.uid,
          kind: ReactionKind.heart,
        )).called(1);
    verifyNever(() => repo.unreact(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
        ));
  });

  test('different kind → react (replace), returns the new kind', () async {
    final res = await useCase(
      params(kind: ReactionKind.fire, current: ReactionKind.heart),
    );

    expect(res, const Right<Failure, ReactionKind?>(ReactionKind.fire));
    verify(() => repo.react(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
          kind: ReactionKind.fire,
        )).called(1);
  });

  test('same kind → unreact (toggle off), returns null', () async {
    final res = await useCase(
      params(kind: ReactionKind.heart, current: ReactionKind.heart),
    );

    expect(res, const Right<Failure, ReactionKind?>(null));
    verify(() => repo.unreact(
          baseId: 'b1'.bid,
          target: _target,
          userId: 'me'.uid,
        )).called(1);
    verifyNever(() => repo.react(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
          kind: any(named: 'kind'),
        ));
  });

  test('repo Left propagates unchanged', () async {
    when(() => repo.react(
          baseId: any(named: 'baseId'),
          target: any(named: 'target'),
          userId: any(named: 'userId'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async => const Left(NetworkFailure('offline')));

    final res = await useCase(params(kind: ReactionKind.sad));

    expect(res, isA<Left<Failure, ReactionKind?>>());
    expect((res as Left<Failure, ReactionKind?>).value, isA<NetworkFailure>());
  });

  test('unshipped target kind is a ValidationFailure with no repo call',
      () async {
    final res = await useCase(params(
      kind: ReactionKind.like,
      target: const ReactionTarget(kind: ReactionTargetKind.story, id: 's1'),
    ));

    expect(res, isA<Left<Failure, ReactionKind?>>());
    expect(
        (res as Left<Failure, ReactionKind?>).value, isA<ValidationFailure>());
    verifyZeroInteractions(repo);
  });
}
