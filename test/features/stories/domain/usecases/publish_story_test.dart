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
/// Three tests are written:
/// 1. Disabled stories → `Left(ValidationFailure)`, repo **never** called.
/// 2. Caption over 280 chars → same short-circuit.
/// 3. Happy path trims `'  hello  '` → repo called once with `caption: 'hello'`.
///
/// Three more are skipped skeletons in this file — that is your task:
/// 4. Accept a caption of exactly 280 characters (other half of the boundary).
/// 5. Forward a whitespace-only caption as null (`verify` only).
/// 6. Optional: disabled failure wins when both rules are broken.
///
/// `PublishStory.call()` has three exits — two early returns and one forward —
/// so three tests is the floor, not the target. The extras pin the limit to
/// one character, cover a translation that does not change the return value,
/// and (optionally) lock rule order.
///
/// Pattern to steal from `test/features/bases/domain/usecases/create_base_test.dart`
/// and `join_base_test.dart`: Arrange (`when`) → Act (`await useCase(...)`) →
/// Assert (`expect` + `verify` / `verifyNever`).
void main() {
  // Fallbacks are process-wide for this file. `setUpAll` runs once; `setUp`
  // below runs before *each* test so a leftover stub cannot leak.
  setUpAll(registerStoriesFallbacks);

  // late -> assigning before anything reads it

  late MockStoryRepository repo;
  late PublishStory useCase;
  late BaseSettings enabledSettings;
  late MediaRef fakeMedia;

  setUp(() {
    // runs before every test in this file (not once)
    // mock acculmulatotes a call history. A fresh MockStoryRepo call per test provides meaning
    // to the verify(...).called(1) assertion
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
        // FIXTURE
        //Repo's scripted reply
        // Repo is stubbed to *return* this. The use case does not build a [Story]
        // scripted reply should match the scenario
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
    // Programs the repo to answer 'publishStory' with the 'Right(story)', whatever argument it is called with

    when(
      () => repo.publishStory(
        // any() ensures its a loose matcher, and that any mismatch would surface as "no matching stub"
        baseId: any(named: 'baseId'),
        authorUserId: any(named: 'authorUserId'),
        media: any(named: 'media'),
        ttl: any(named: 'ttl'),
        caption: any(named: 'caption'),
      ),
    ).thenAnswer((_) async => Right(story));
  }

  void verifyRepoNeverCalled() {
    // Runs BEFORE any I/O is attempted
    // isolate the test
    verifyNever(
      () => repo.publishStory(
        baseId: any(named: 'baseId'),
        authorUserId: any(named: 'authorUserId'),
        media: any(named: 'media'),
        ttl: any(named: 'ttl'),
        caption: any(named: 'caption'),
      ),
    );

    // setUp() -> fresh mock + valid by default fixtures PER TEST
    // fakeStory() -> the repo's scripted reply (not being tested here)
    // stubPublishSuccess() -> scripts the success reply (required)
    // verifyRepoNeverCalled() -> proves no actual I/O was attempted
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

    test(
      'accepts a caption of exactly 280 characters',
      () async {
        stubPublishSuccess(fakeStory(caption: 'x' * 280));

        final result = await useCase(
          PublishStoryParams(
            baseId: const BaseId('b1'),
            authorUserId: const UserId('u1'),
            media: fakeMedia,
            settings: enabledSettings,
            caption: 'x' * 280,
            ),
        );

        expect(result, isA<Right<Failure, Story>>());
        verify(() => repo.publishStory(
          baseId: const BaseId('b1'), 
          authorUserId: const UserId('u1'), 
          media: fakeMedia, 
          ttl: const Duration(hours: 24),
          caption: 'x' * 280,
          ),
        );
      verifyRepoNeverCalled();
        // TODO(angelo): Arrange — `stubPublishSuccess(fakeStory(caption:
        // 'x' * 280))`. This one succeeds, so it needs a stub (unlike the
        // two rejections above). Adjacent to the 281 test on purpose: the
        // two are one claim in two halves. Without this, any limit between
        // 5 (`'hello'`) and 281 passes — including `>= 280`.
        //
        // TODO(angelo): Act — `caption: 'x' * 280`.
        //
        // TODO(angelo): Assert — Right, and the caption crossed the seam
        // untruncated. Matchers are fine for args this test does not care
        // about; use the exact value for `caption`.
      },
  
    );

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

    test(
      'forwards a whitespace-only caption as null',
      () async {
        // TODO(angelo): Arrange — `stubPublishSuccess(fakeStory(caption:
        // null))`. Use `'   '` rather than `''` as the input — it also
        // proves trim happens before the empty check, which `''` would not.
        stubPublishSuccess(fakeStory(caption: '   '));

        //
        // TODO(angelo): Act — `caption: '   '`.
        final result = await useCase(
          PublishStoryParams(
            baseId: const BaseId('b1'),
            authorUserId: const UserId('u1'),
            media: fakeMedia,
            settings: enabledSettings,
            caption: '   ',
            ),
        );
        //
        // TODO(angelo): Assert — `verify` only. `caption: null`, exact.
        // The use case RETURNS `Right(story)` — the value we scripted.
        // Identical whether the rule fired or not, so an `expect` on
        // `result` cannot prove this behaviour. It exists only at the
        // seam: `verify` is the sole instrument.
        expect(result, isA<Right<Failure, Story>> ());
        verify(() => repo.publishStory(
          baseId: const BaseId('b1'), 
          authorUserId: const UserId('u1'), 
          media: fakeMedia,
          ttl: const Duration(hours: 24),
          caption: null,
          ),
          ).called(1);
      });

    test(
      'returns the disabled failure when both rules are broken',
      () async {
        // TODO(angelo): Arrange — `storiesEnabled: false` AND a caption of
        // 281+ characters. No stub: if the disabled gate runs first the
        // port is never reached.
        //
        // TODO(angelo): Act — `await useCase(...)`.
        //
        // TODO(angelo): Assert — `Left(ValidationFailure)` with the
        // "stories are disabled" message, not the caption-length message.
        // Then `verifyRepoNeverCalled()`.
      },
      skip: 'TODO(angelo): optional — write this test — rule order',
    );
  });
}

// ============================================================
// ASSIGNMENT — PublishStory suite (in progress)
// ------------------------------------------------------------
// TYPE:        Blank problem — three tests to write
// TIME:        ~45 min solo  (~10 reading, ~35 writing)
//              Estimates are generous. Faster is expected.
// COMES BEFORE: Assignment 1 (list_active_stories)
//
// LEARNING OBJECTIVES
//   After this you should be able to:
//   1. Explain why a behaviour with no effect on the return value can only
//      be tested with `verify`.
//   2. Pin a numeric limit with a pair of tests — accept at N, reject at
//      N+1 — so a `>=` typo cannot hide.
//   3. Combine two illegal inputs and read the failure message to see
//      which rule ran first.
//
// PROVIDED
//   - The three written tests in this file (disabled, 281 chars, trim).
//   - `stubPublishSuccess` and `verifyRepoNeverCalled`.
//   - Three skipped skeletons in the `PublishStory` group.
//
// YOUR TASK
//   1. Write the 280-char test from its skeleton (it belongs next to the
//      281 test). Remove `skip:`. Run it. Watch it pass or fail.
//   2. Write the whitespace-as-null test. `verify` is the assertion;
//      an `expect` on `result` does not count.
//   3. Optional: write the rule-order test, or log why you skipped it.
//
// SUBMIT
//   - The 280-char test passing (no `skip:`).
//   - The whitespace-as-null test passing (no `skip:`).
//   - The optional test passing, or a one-line note that you left it.
//
// ACCEPTANCE
//   - fvm dart analyze clean
//   - all listed tests pass
//
// >> HINT: The 280 test needs a stub; the two rejections above do not.
// >> HINT: Input `'   '` (three spaces), not `''`. Empty would not prove
// trim-before-empty. Script `fakeStory(caption: null)` so the reply
// matches the seam.
// >> HINT: On the optional test, copyWith `storiesEnabled: false` and pass
// a 281-char caption. The message must be the disabled one.
// ============================================================
