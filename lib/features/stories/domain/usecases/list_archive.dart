import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

class ListArchiveParams {
  const ListArchiveParams({required this.baseId, required this.settings});
  final BaseId baseId;
  // Lives on *params*, not on StoryRepository.listArchive. The use case
  // reads storiesArchiveEnabled here; the port receives only the base id.
  final BaseSettings settings;
}

/// Loads **archived** stories for one base, if that base keeps an archive.
///
/// *Archived* means a story that already expired (its time-to-live ran out)
/// and was kept instead of deleted, so members can still look back at it
/// ("highlights"). That keep-or-delete choice is a per-base setting:
/// [BaseSettings.storiesArchiveEnabled]. *Base settings* are the knobs for
/// one base (stories on/off, archive on/off, how long a story lives). The
/// screen that calls this use case reads those knobs and passes them in
/// [ListArchiveParams.settings]. This class does not fetch settings itself.
///
/// Two rules meet here, in two different layers:
/// 1. **Feature flag (this file):** if archive is turned off for the base,
///    do not list anything — return `Left(ValidationFailure)` and never
///    call the port.
/// 2. **Row filter (the port):** [StoryRepository.listArchive] returns only
///    archived rows. You do not filter the list in this file.
class ListArchive implements UseCase<List<Story>, ListArchiveParams> {
  const ListArchive(this.repo);
  final StoryRepository repo;

  @override
  // `async` here, unlike ListActiveStories, so the guard below can return a
  // Left directly instead of wrapping it in Future.value(...).
  Future<Either<Failure, List<Story>>> call(ListArchiveParams p) async {
    // TODO(angelo): Rule 1 — refuse when the base has archive turned off.
    // Return Left(ValidationFailure(...)) here, before the line below runs.
    // The test `rejects when storiesArchiveEnabled is false` fails until you do.

    return repo.listArchive(p.baseId); // Rule 2 — provided
  }
}

// ============================================================
// ASSIGNMENT 2 of 4 — Stories use cases
// ------------------------------------------------------------
// TYPE:        Completion problem — write the failing test, then the guard
// TIME:        ~90 min solo  (~15 reading, ~55 writing, ~20 running and fixing)
//              Estimates are generous. Faster is expected once the pattern
//              clicks — that is the point of doing them in order.
// PREREQS:     Assignment 1 (`list_active_stories`) — worked example
//
// LEARNING OBJECTIVES
//   After this you should be able to:
//   1. Explain why a feature-flag check must run before the port is called.
//   2. Use `copyWith` to vary one field of a valid fixture so the field under
//      test is the only field that appears in that test.
//   3. Use `verifyZeroInteractions` to prove the port was never touched.
//
// PROVIDED
//   - The enabled branch: `return repo.listArchive(p.baseId);`
//   - `test/features/stories/domain/usecases/list_archive_test.dart`
//     success test, fully written.
//   - Two skipped skeletons in that file (refusal + failure-passthrough).
//
// YOUR TASK
//   1. Write the refusal test from its skeleton. Run it. Watch it fail.
//   2. Then fill Rule 1 in `call` (the guard). Do not change Rule 2.
//   3. Write the failure-passthrough test from its skeleton.
//
// SUBMIT
//   - The refusal test passing (no `skip:`).
//   - The guard in `call`.
//   - The failure-passthrough test passing (no `skip:`).
//
// ACCEPTANCE
//   - fvm dart analyze clean
//   - all listed tests pass
//   - `settings` is never an argument to `repo.listArchive`
//
// >> HINT: Use `ValidationFailure`, not any other `Failure` subclass. A
// message like `'Story archive is disabled for this base'` is enough.
// >> HINT: On the refusal test use `verifyZeroInteractions(repo)`. It asserts
// the port was never touched at all, not just that `listArchive` was skipped —
// a stronger claim, and it needs no matchers. Do not stub the port in that
// test: stubbing a response nobody should consume makes the test read as a lie,
// and the absence of a stub is part of the claim.
// >> HINT: In `setUp`, build a valid `BaseSettings` (archive on, the defaults).
// In the refusal test only, `copyWith(storiesArchiveEnabled: false)`. Default
// fixtures to valid and override one field per test so the field a test is
// varying is the only field that appears in it.
// >> HINT: For the failure-passthrough test, stub the port with
// `Left(CacheFailure('...'))`, assert the result is
// `isA<Left<Failure, List<Story>>>()` and `isA<CacheFailure>()`, and that the
// message is unchanged — type alone still passes if the use case replaces the
// message with something generic, which is exactly the detail a caller needs.
// >> HINT: Before the guard exists, the refusal test fails with mocktail's
// "Bad state: No method stub" rather than a clean assertion. That error IS the
// finding — it means the port was called when it should not have been. Once
// the guard returns Left, the port is never reached and the test passes with
// no stub at all.
// ============================================================
