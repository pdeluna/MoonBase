import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';

class ToggleReactionParams {
  const ToggleReactionParams({
    required this.baseId,
    required this.target,
    required this.userId,
    required this.kind,
    required this.current,
  });

  final BaseId baseId;
  final ReactionTarget target;
  final UserId userId;

  /// The kind the user just tapped.
  final ReactionKind kind;

  /// The user's existing reaction on this target, or null.
  final ReactionKind? current;
}

/// Encodes the one-reaction-per-`(user, target)` invariant:
///
/// - tapping the kind already cast ⇒ **toggle off** (`unreact`) ⇒ `Right(null)`
/// - tapping a different kind (or none cast) ⇒ **replace/create** (`react`)
///   ⇒ `Right(kind)`
///
/// Returns the resulting kind so the caller can reconcile optimistic state.
/// Reacting to a target kind that has not shipped is a `ValidationFailure`
/// here and a rules denial server-side — the two must agree (trigger #17).
class ToggleReaction implements UseCase<ReactionKind?, ToggleReactionParams> {
  const ToggleReaction(this.repo);

  final ReactionRepository repo;

  @override
  Future<Either<Failure, ReactionKind?>> call(ToggleReactionParams p) async {
    if (!p.target.kind.isShipped) {
      return Left(ValidationFailure(
        'Reactions on ${p.target.kind.name}s are not available yet.',
      ));
    }

    if (p.current == p.kind) {
      final res = await repo.unreact(
        baseId: p.baseId,
        target: p.target,
        userId: p.userId,
      );
      return res.map((_) => null);
    }

    final res = await repo.react(
      baseId: p.baseId,
      target: p.target,
      userId: p.userId,
      kind: p.kind,
    );
    return res.map((_) => p.kind);
  }
}
