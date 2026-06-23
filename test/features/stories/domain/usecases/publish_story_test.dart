import 'package:flutter_test/flutter_test.dart';

// TODO(stories Step 5.1): uncomment as you write the tests.
//
// import 'package:mocktail/mocktail.dart';
// import 'package:moonbase_skeleton/core/either.dart';
// import 'package:moonbase_skeleton/core/failure.dart';
// import 'package:moonbase_skeleton/core/ids.dart';
// import 'package:moonbase_skeleton/core/sync_status.dart';
// import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
// import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
// import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
// import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
// import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';
// import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
//
// class _MockStoryRepo extends Mock implements StoryRepository {}

/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 7.1.
///
/// Three tests to write, in this order:
///
/// | Test name                                     | Setup                                                                                   | Expectation                                                                              |
/// | --------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
/// | `rejects when storiesEnabled is false`        | `settings.copyWith(storiesEnabled: false)`                                              | Result is a `Left`; `verifyNever(() => repo.publishStory(...))`                          |
/// | `rejects captions over 280 chars`             | `caption = 'x' * 281`                                                                   | Result is a `Left<ValidationFailure, _>`; `verifyNever(() => repo.publishStory(...))`    |
/// | `trims caption and forwards on success`       | Stub `repo.publishStory(...)` → `Right(fakeStory)`; pass `caption: '  hello  '`         | Result is a `Right`; `verify(... caption: 'hello' ...).called(1)`                        |
///
/// The point of these tests, the payoff to feel here: **you can fully test
/// the use case without a single line of widget code, without
/// `SharedPreferences`, and without the file system.** That is the moment
/// "why all this boilerplate?" usually clicks. Sit with it.
///
/// Use `mocktail` (already in `pubspec.yaml` dev_dependencies):
///
/// ```dart
/// class _MockStoryRepo extends Mock implements StoryRepository {}
/// ```
///
/// For the `Right` test you'll need a "fake `Story`" to return. Build it
/// inline — it never leaves the test:
///
/// ```dart
/// final fakeStory = Story(/* ...minimum valid fields... */);
/// when(() => repo.publishStory(
///       baseId: any(named: 'baseId'),
///       userId: any(named: 'userId'),
///       media: any(named: 'media'),
///       ttl: any(named: 'ttl'),
///       caption: any(named: 'caption'),
///     )).thenAnswer((_) async => Right(fakeStory));
/// ```
///
/// Mocktail with named-parameter methods requires `registerFallbackValue`
/// for any complex types you pass through `any(named: ...)`. For this test
/// the only complex type that needs a fallback is `MediaRef`. Register it
/// once in a `setUpAll`:
///
/// ```dart
/// setUpAll(() {
///   registerFallbackValue(
///     const MediaRef(
///       id: MediaId('fallback'),
///       type: MediaType.image,
///       storageKey: 'fallback',
///     ),
///   );
/// });
/// ```
void main() {
  // TODO(stories Step 5.1): write the three tests described in the
  // doc-comment above. Mirror the structure used by existing chat use case
  // tests under `test/features/chat/domain/usecases/`.
  test('TODO: publish_story_test scaffold — see file doc-comment', () {
    // Intentionally trivial so the suite is green on the scaffold branch.
    // Replace this test with the three real ones from Section 7.1 of the
    // first-steps guide.
    expect(true, isTrue);
  });
}
