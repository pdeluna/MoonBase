// lots of unused imports, will check for missing functionality or data during testing
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_active_stories.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/stream_active_stories.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/delete_story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/expire_and_archive.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_archive.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  throw UnimplementedError('Provide StoryRepository in app wiring (lib/main.dart). ''See assignments/STORIES_FIRST_STEPS.md Section 5.',
  );
});

//provider scheme/pathway to usecase files
final publishStoryUsecaseProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final listActiveStoriesProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final streamActiveStoriesProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final deleteStoryProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final expireAndArchiveProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final listArchiveProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
