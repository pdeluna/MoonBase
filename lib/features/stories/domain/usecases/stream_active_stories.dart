import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

/// Live list of active stories for one base.
///
/// Not a UseCase — returns a Stream, not Future<Either>. Do not filter
/// expired/archived rows here; that is StoryRepository.streamActive.
class StreamActiveStories {
  const StreamActiveStories(this.repo);
  final StoryRepository repo;

  Stream<List<Story>> call(BaseId baseId) => repo.streamActive(baseId);
}
