import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_active_stories.dart';

import '../../../../test_utils/mocks_stories.dart';

/// Worked example suite for [ListActiveStories] — study this file, then
/// finish the skipped test.
///
/// What this proves (and what it deliberately does **not**):
/// - We fully exercise the use case with a [MockStoryRepository].
/// - No widgets, no `SharedPreferences`, no file system.
/// - The use case does not build a [Story]; it forwards `baseId` and returns
///   whatever `Either` the port produced.
///
/// Two exits from `call` — the floor is 2:
/// 1. Success path — written below.
/// 2. Failure-passthrough — skipped skeleton; that is your task.
void main() {
  // Fallbacks are process-wide for this file. `setUpAll` runs once; `setUp`
  // below runs before *each* test so a leftover stub cannot leak.
  setUpAll(registerStoriesFallbacks);

  late MockStoryRepository repo;
  late ListActiveStories useCase;
  late MediaRef fakeMedia;

  setUp(() {
    // Fresh mock per test so `verify(...).called(1)` cannot see a prior test.
    repo = MockStoryRepository();
    useCase = ListActiveStories(repo);
    fakeMedia = const MediaRef(
      id: MediaId('m1'),
      type: MediaType.image,
      storageKey: 'b1/abc.jpg',
    );
  });

  /// The repo is stubbed to *return* this. The use case does not build a
  /// [Story] — `id` / `createdAt` are repository concerns. We only need a
  /// valid instance so `Right([fakeStory()])` type-checks.
  Story fakeStory() => Story(
        id: const StoryId('s1'),
        baseId: const BaseId('b1'),
        authorUserId: const UserId('u1'),
        media: fakeMedia,
        ttl: const Duration(hours: 24),
        createdAt: DateTime.utc(2026, 6, 12),
      );

  group('ListActiveStories', () {
    test('forwards baseId to repo.listActive and returns the result', () async {
      // Arrange — stub *before* calling. If you skip `when`, mocktail throws
      // "Bad state: No method stub" because Mock has no real body.
      //
      // `thenAnswer`, not `thenReturn`: `listActive` returns a Future.
      // `thenReturn` is for sync values; a Future needs a callback that
      // *produces* the Future each time the stub is hit.
      //
      // Loose matcher in `when`: we do not care which BaseId the stub
      // accepts — any call should get this Right. Exact value lives in
      // `verify`, so a failure message points at the forwarding contract.
      final story = fakeStory();
      when(() => repo.listActive(any()))
          .thenAnswer((_) async => Right([story]));

      // Act
      final result = await useCase(
        const ListActiveStoriesParams(baseId: BaseId('b1')),
      );

      // Assert — the list we scripted is what came back (use case did not
      // wrap, filter, or replace it). Then the seam: exact baseId, once.
      expect(result, isA<Right<Failure, List<Story>>>());
      result.match(
        (_) => fail('expected Right, got Left'),
        (stories) {
          expect(stories, hasLength(1));
          expect(stories.single, story);
        },
      );
      verify(() => repo.listActive(const BaseId('b1'))).called(1);
      verifyNoMoreInteractions(repo);
    });

    test(
      'propagates a repository failure unchanged',
      () async {
        // TODO(angelo): Arrange — stub `repo.listActive(any())` with
        // `Left(CacheFailure('...'))`. Use `thenAnswer`, not `thenReturn`.
        //
        // TODO(angelo): Act — `await useCase(ListActiveStoriesParams(...))`.
        //
        // TODO(angelo): Assert — `isA<Left<Failure, List<Story>>>()`,
        // `isA<CacheFailure>()`, *and* `failure.message` equals the string
        // you stubbed. Type alone still passes if the use case swapped the
        // message for something generic.
      },
      skip: 'TODO(angelo): write this test — Assignment 1',
    );
  });
}
