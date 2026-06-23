import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

// TODO(stories Step 3): once the use cases exist in
// `lib/features/stories/domain/usecases/`, import each one here and expose
// it via a `Provider` that reads `storyRepositoryProvider`. Mirror exactly
// `lib/features/chat/presentation/providers/chat_providers.dart` lines 8-14.
//
// import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
// import 'package:moonbase_skeleton/features/stories/domain/usecases/list_active_stories.dart';
// import 'package:moonbase_skeleton/features/stories/domain/usecases/stream_active_stories.dart';
// import 'package:moonbase_skeleton/features/stories/domain/usecases/delete_story.dart';
// import 'package:moonbase_skeleton/features/stories/domain/usecases/expire_and_archive.dart';

/// Provider seam for the Stories repository.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 5.
///
/// **Why does this throw?** Because the domain and presentation layers must
/// not transitively import `dart:io` or `shared_preferences`. They depend
/// only on this *token* and the abstract `StoryRepository` type. The
/// concrete `StoryRepositoryImpl` (with its `SharedPreferences` baggage) is
/// imported in exactly one place: `lib/main.dart`, where it provides an
/// override on the `ProviderScope`.
///
/// Reading this provider before that override is wired is a programming
/// error — hence `UnimplementedError` rather than `null`.
///
/// Mirror: `lib/features/chat/presentation/providers/chat_providers.dart`
/// lines 8-10.
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  throw UnimplementedError(
    'Provide StoryRepository in app wiring (lib/main.dart). '
    'See assignments/STORIES_FIRST_STEPS.md Section 5.',
  );
});

// TODO(stories Step 3): once each use case is written, add a provider here
// in the same one-liner style used by chat_providers.dart, e.g.
//
//   final publishStoryUseCaseProvider =
//       Provider((ref) => PublishStory(ref.read(storyRepositoryProvider)));
//
// Do NOT create the providers until the use case classes exist — a stub
// provider that throws here is worse than a missing one, because it lies
// about the type.
