import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

class ExpireAndArchiveStoriesParams {
  const ExpireAndArchiveStoriesParams({required this.baseId});
  final BaseId baseId;
}

/// Asks the repository to sweep expired stories for one base.
///
/// Archive-vs-hard-delete, and `MediaStorage.delete`, live in
/// `StoryRepositoryImpl` (Phase 3 local sweep). This class forwards
/// [ExpireAndArchiveStoriesParams.baseId] and returns the port's `Either`.
class ExpireAndArchiveStories
    implements UseCase<Unit, ExpireAndArchiveStoriesParams> {
  const ExpireAndArchiveStories(this.repo);
  final StoryRepository repo;

  @override
  Future<Either<Failure, Unit>> call(ExpireAndArchiveStoriesParams p) {
    return repo.expireAndArchive(p.baseId);
  }
}
