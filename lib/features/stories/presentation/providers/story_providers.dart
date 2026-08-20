// lots of unused imports, will check for missing functionality or data during testing
// you had the right idea, think of this provider file as a 'fetch land' for all our use cases.
// we don't actually need to import each dart file. it's just the 'search' effect in place
// until main.dart 'cracks' it. we're just making sure main.dart wires (overrides) each using the real
// StoryRepositoryImpl before the app even loads. We intentionally throw so that if we override too early or
// the Impl file is missing anything, we crash loud (deck is missing a land) - p
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_active_stories.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_archive.dart';
//import 'package:moonbase_skeleton/features/stories/domain/usecases/stream_active_stories.dart';
//import 'package:moonbase_skeleton/features/stories/domain/usecases/delete_story.dart';
//import 'package:moonbase_skeleton/features/stories/domain/usecases/expire_and_archive.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  throw UnimplementedError('Provide StoryRepository in app wiring (lib/main.dart). ''See assignments/STORIES_FIRST_STEPS.md Section 5.',
  );
});

//provider scheme/pathway to usecase files
// included as each use case lands
final publishStoryUsecaseProvider = Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
final listActiveStoriesProvider = Provider((ref) => ListActiveStories(ref.read(storyRepositoryProvider)));
final listArchiveProvider = Provider((ref) => ListArchive(ref.read(storyRepositoryProvider)));

// TODO(angelo): uncomment when the use case lands (Assignment 3 / 4).
// final streamActiveStoriesProvider = Provider((ref) => StreamActiveStories(ref.read(storyRepositoryProvider)));

// TODO(angelo): uncomment when the use case lands (Assignment 3 / 4).
// final deleteStoryProvider = Provider((ref) => DeleteStory(ref.read(storyRepositoryProvider)));

// Expiry runs server-side (scheduled Cloud Function). No client use case.
// final expireAndArchiveProvider = Provider((ref) => ExpireAndArchive(ref.read(storyRepositoryProvider)));
