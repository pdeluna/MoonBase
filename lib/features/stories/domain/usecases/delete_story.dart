import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_role.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

class DeleteStoryParams {
  const DeleteStoryParams({
    required this.id,
    required this.actingUserId,
    required this.authorUserId,
    required this.actingRole,
  });

  final StoryId id;
  final UserId actingUserId;
  final UserId authorUserId;
  final BaseRole actingRole;
}

/// Deletes one story if the actor is allowed to.
///
/// authorUserId is passed in from the Story the controller already has.
/// Do not add getStory on the port.
class DeleteStory implements UseCase<Unit, DeleteStoryParams> {
  const DeleteStory(this.repo);
  final StoryRepository repo;

  @override
  Future<Either<Failure, Unit>> call(DeleteStoryParams p) async {
    // Allowed: actingUserId == authorUserId OR actingRole.isOwnerOrAdmin.
    // Otherwise Left(PermissionDeniedFailure) and do not call the port.
    return repo.deleteStory(p.id);
  }
}
