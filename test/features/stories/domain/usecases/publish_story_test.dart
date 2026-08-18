import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';

import '../../../../test_utils/mocks_stories.dart';

/// First Stories use-case suite — pair-review with the junior.
///
/// What this proves (and what it deliberately does **not**):
/// - We fully exercise [PublishStory] with a [MockStoryRepository].
/// - No widgets, no `SharedPreferences`, no Firebase, no file system.
/// - That is the payoff of the port: validation lives in the use case; persist
///   lives behind `StoryRepository`. Swap the mock for a real impl later
///   without rewriting these tests.
///
/// Three contracts, in this order:
/// 1. Disabled stories → `Left(ValidationFailure)`, repo **never** called.
/// 2. Caption over 280 chars → same short-circuit.
/// 3. Happy path trims `'  hello  '` → repo called once with `caption: 'hello'`.
///
/// Pattern to steal from `test/features/bases/domain/usecases/create_base_test.dart`
/// and `join_base_test.dart`: Arrange (`when`) → Act (`await useCase(...)`) →
/// Assert (`expect` + `verify` / `verifyNever`).
void main() {
  // Fallbacks are process-wide for this file. `setUpAll` runs once; `setUp`
  // below runs before *each* test so a leftover stub cannot leak.
  setUpAll(registerStoriesFallbacks);

  late MockStoryRepository repo;
  late PublishStory useCase;
  late BaseSettings enabledSettings;
  late MediaRef fakeMedia;

  setUp(() {
    repo = MockStoryRepository();
    useCase = PublishStory(repo);
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
  /// [Story] — `id` / `createdAt` are repository concerns. We only need a
  /// valid instance so `Right(fakeStory)` type-checks.
  Story fakeStory({String? caption}) => Story(
        id: const StoryId('s1'),
        baseId: const BaseId('b1'),
        authorUserId: const UserId('u1'),
        media: fakeMedia,
        ttl: const Duration(hours: 24),
        createdAt: DateTime.utc(2026, 6, 12),
        caption: caption,
      );

  /// Shared `any(named: …)` matcher for `publishStory`. Using it in both
  /// `when` and `verifyNever` keeps the tests honest: we never care which
  /// IDs were forwarded on a *rejected* call, only that the call did not
  /// happen.
  void stubPublishSuccess(Story story) {
    when(
      () => repo.publishStory(
        baseId: any(named: 'baseId'),
        authorUserId: any(named: 'authorUserId'),
        media: any(named: 'media'),
        ttl: any(named: 'ttl'),
        caption: any(named: 'caption'),
      ),
    ).thenAnswer((_) async => Right(story));
  }

  void verifyRepoNeverCalled() {
    verifyNever(
      () => repo.publishStory(
        baseId: any(named: 'baseId'),
        authorUserId: any(named: 'authorUserId'),
        media: any(named: 'media'),
        ttl: any(named: 'ttl'),
        caption: any(named: 'caption'),
      ),
    );
  }

  group('PublishStory', () {
    test('rejects when storiesEnabled is false', () async {
      // Arrange — copyWith is the whole point of BaseSettings being a value
      // object: flip one flag, keep the rest. The use case must not reach
      // the repo when the base has stories turned off.
      final disabled = enabledSettings.copyWith(storiesEnabled: false);

      // Act
      final result = await useCase(
        PublishStoryParams(
          baseId: const BaseId('b1'),
          authorUserId: const UserId('u1'),
          media: fakeMedia,
          settings: disabled,
        ),
      );

      // Assert — Left, and specifically ValidationFailure (not Cache/Network:
      // nothing was persisted, the input was illegal).
      expect(result, isA<Left<Failure, Story>>());
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected Left(ValidationFailure), got Right'),
      );
      verifyRepoNeverCalled();
    });

    test('rejects captions over 280 characters', () async {
      // Arrange — 281 of 'x' is one past the cap. Length is checked *after*
      // trim, so we do not pad with spaces here (that would be a different
      // test: whitespace-only becoming null).
      final result = await useCase(
        PublishStoryParams(
          baseId: const BaseId('b1'),
          authorUserId: const UserId('u1'),
          media: fakeMedia,
          settings: enabledSettings,
          caption: 'x' * 281,
        ),
      );

      expect(result, isA<Left<Failure, Story>>());
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected Left(ValidationFailure), got Right'),
      );
      verifyRepoNeverCalled();
    });

    test('trims caption and forwards to repo on success', () async {
      // Arrange — stub *before* calling. If you skip `when`, mocktail throws
      // "Bad state: No method stub" because Mock has no real body.
      stubPublishSuccess(fakeStory(caption: 'hello'));

      // Act — leading/trailing spaces are a UI accident; the use case owns
      // the trim so every caller (screen, later a Cloud Function, a test)
      // gets the same stored caption.
      final result = await useCase(
        PublishStoryParams(
          baseId: const BaseId('b1'),
          authorUserId: const UserId('u1'),
          media: fakeMedia,
          settings: enabledSettings,
          caption: '  hello  ',
        ),
      );

      // Assert — Right, and the repo saw the trimmed caption *and* ttl
      // taken from settings.storyTtl (default 24h). Exact args, called once.
      expect(result, isA<Right<Failure, Story>>());
      verify(
        () => repo.publishStory(
          baseId: const BaseId('b1'),
          authorUserId: const UserId('u1'),
          media: fakeMedia,
          ttl: const Duration(hours: 24),
          caption: 'hello',
        ),
      ).called(1);
      verifyNoMoreInteractions(repo);
    });
  });
}
