import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_archive.dart';

import '../../../../test_utils/mocks_stories.dart';

/// Completion-problem suite for [ListArchive].
///
/// The success path is written. Write the refusal test first (watch it fail),
/// then the guard in `list_archive.dart`, then the failure-passthrough test.
///
/// Three exits from `call` — the floor is 3:
/// 1. Archive disabled → `Left(ValidationFailure)`, port never touched.
/// 2. Archive enabled → forward to `listArchive` (written below).
/// 3. Port returns `Left` → same `Left` comes out (passthrough).
void main() {
  setUpAll(registerStoriesFallbacks);

  late MockStoryRepository repo;
  late ListArchive useCase;
  late BaseSettings enabledSettings;
  late MediaRef fakeMedia;

  setUp(() {
    repo = MockStoryRepository();
    useCase = ListArchive(repo);
    // Valid by default (storiesArchiveEnabled: true). Flip one field per
    // test with copyWith so the field you are varying is the only one that
    // appears in that test.
    enabledSettings = BaseSettings(
      baseId: const BaseId('b1'),
      updatedAt: DateTime.utc(2026, 6, 12),
      updatedByUserId: const UserId('u1'),
    );
    fakeMedia = const MediaRef(
      id: MediaId('m1'),
      type: MediaType.image,
      storageKey: 'b1/abc.jpg',
    );
  });

  /// The repo is stubbed to *return* this. The use case does not build a
  /// [Story] — we only need a valid instance so `Right([fakeStory()])`
  /// type-checks.
  Story fakeStory() => Story(
        id: const StoryId('s1'),
        baseId: const BaseId('b1'),
        authorUserId: const UserId('u1'),
        media: fakeMedia,
        ttl: const Duration(hours: 24),
        createdAt: DateTime.utc(2026, 6, 12),
        archived: true,
      );

  group('ListArchive', () {
    test(
      'rejects when storiesArchiveEnabled is false',
      () async {
        // TODO(angelo): Arrange — `enabledSettings.copyWith(storiesArchiveEnabled:
        // false)`. Do **not** stub the port. This test's claim is that the
        // port is never touched: a stub would be a response nobody should
        // consume, and the absence of a stub is part of that claim.
        //
        // TODO(angelo): Act — `await useCase(ListArchiveParams(...))`.
        //
        // TODO(angelo): Assert — `Left(ValidationFailure)`, then
        // `verifyZeroInteractions(repo)`.
      },
      skip:
          'TODO(angelo): write this test first — it will fail until the guard exists',
    );

    test('forwards to repo.listArchive when storiesArchiveEnabled is true',
        () async {
      // Arrange — stub *before* calling. `thenAnswer`, not `thenReturn`:
      // `listArchive` returns a Future. Loose `any()` in `when`; exact
      // `BaseId('b1')` in `verify`.
      final story = fakeStory();
      when(() => repo.listArchive(any()))
          .thenAnswer((_) async => Right([story]));

      // Act — settings stay at the setUp default (archive on). No copyWith.
      final result = await useCase(
        ListArchiveParams(
          baseId: const BaseId('b1'),
          settings: enabledSettings,
        ),
      );

      // Assert — scripted list came back unchanged; seam saw the base id
      // once; settings were not forwarded (the port has no such argument).
      expect(result, isA<Right<Failure, List<Story>>>());
      result.match(
        (_) => fail('expected Right, got Left'),
        (stories) {
          expect(stories, hasLength(1));
          expect(stories.single, story);
        },
      );
      verify(() => repo.listArchive(const BaseId('b1'))).called(1);
      verifyNoMoreInteractions(repo);
    });

    test(
      'propagates a repository failure unchanged',
      () async {
        // TODO(angelo): Arrange — stub `repo.listArchive(any())` with
        // `Left(CacheFailure('...'))`. Archive stays enabled (setUp default).
        //
        // TODO(angelo): Act — `await useCase(ListArchiveParams(...))`.
        //
        // TODO(angelo): Assert — `isA<Left<Failure, List<Story>>>()`,
        // `isA<CacheFailure>()`, *and* `failure.message` equals the string
        // you stubbed.
      },
      skip: 'TODO(angelo): write this test — Assignment 2',
    );
  });
}
