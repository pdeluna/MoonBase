import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

class ListActiveStoriesParams {
  const ListActiveStoriesParams({required this.baseId});
  final BaseId baseId;
}

/// Loads the **active** stories for one base.
///
/// A *use case* is a single user intent with a name: here, "show me the stories
/// that are still live in this base." A *story* is one piece of media plus an
/// optional caption, owned by one author, that disappears after its time-to-live
/// (TTL). **Active** means not past that TTL and not moved to the archive.
///
/// This class does not talk to disk. It talks to [StoryRepository], an abstract
/// *port* (promises with no storage details behind them). Tests pass a fake
/// port; the real app later passes a SharedPreferences-backed one. Either way,
/// this file stays the same.
///
/// The port already drops expired and archived rows on [StoryRepository.listActive].
/// This use case has no extra checks — it forwards [ListActiveStoriesParams.baseId]
/// and returns the port's result.
///
/// It exists to lock in the shape: a Params class, a constructor that takes
/// the port, and `call` returning `Either` (`Left` = failure, `Right` =
/// success). Later assignments add rules in front of the port call; this
/// one has none.
class ListActiveStories
    implements UseCase<List<Story>, ListActiveStoriesParams> {
  const ListActiveStories(this.repo);
  final StoryRepository repo;

  @override
  Future<Either<Failure, List<Story>>> call(ListActiveStoriesParams p) {
    // Either is already the error channel; guard() lives in the data layer.
    // No await: we return the Future the port already made. No try/catch:
    // a failure comes back as Left, not as a thrown exception.
    return repo.listActive(p.baseId);
  }
}

// ============================================================
// ASSIGNMENT 1 of 4 — Stories use cases
// ------------------------------------------------------------
// TYPE:        Worked example — study, do not rewrite
// TIME:        ~45 min solo  (~25 reading, ~20 writing)
//              Estimates are generous. Faster is expected once the pattern
//              clicks — that is the point of doing them in order.
// PREREQS:     PublishStory (done)
//
// LEARNING OBJECTIVES
//   After this you should be able to:
//   1. Explain why a use case forwards an Either unchanged — no await, no
//      try/catch — and where failures actually become Left.
//   2. Distinguish loose matchers in `when` from exact values in `verify`.
//   3. Write a failure-passthrough assertion that checks subtype *and*
//      message, not type alone.
//
// PROVIDED
//   - `call` — one-line forward to `repo.listActive(p.baseId)`.
//   - `test/features/stories/domain/usecases/list_active_stories_test.dart`
//     Test 1 (success path), fully written and passing.
//   - Test 2 as a skipped skeleton in that same file.
//
// YOUR TASK
//   1. Read `call` and Test 1. Do not rewrite them.
//   2. Write Test 2 from the skeleton: remove `skip:` and fill Arrange /
//      Act / Assert.
//
// SUBMIT
//   - The failure-passthrough test passing (no `skip:`).
//
// ACCEPTANCE
//   - fvm dart analyze clean
//   - all listed tests pass
//
// >> HINT: `verifyNever` is unnecessary here: the port *should* be called.
// >> HINT: Stub the port with `Left(CacheFailure('...'))`, assert the result
// is `isA<Left<Failure, List<Story>>>()` and `isA<CacheFailure>()`, and that
// the message is unchanged — type alone still passes if the use case replaces
// the message with something generic, which is exactly the detail a caller
// needs.
// ============================================================
