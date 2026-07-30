// TODO(stories Step 4): uncomment these imports as you declare method
// signatures that use them. Listed here so you can see the expected
// dependency surface at a glance — and so this scaffold stub stays
// lint-clean (no unused imports).
//
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
import 'package:video_player/video_player.dart';

/// Abstract port for the Stories feature.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 6.
///
/// Mirror: `lib/features/chat/domain/repositories/chat_repository.dart`
/// (shape and doc-comment convention).
///
/// Required methods (Phase 3 DoD Section 2.2.2):
///
/// | Method               | Signature (high level)                                                                                                          | Notes                                                                                          |
/// | -------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
/// | `publishStory`       | `Future<Either<Failure, Story>>` with `{required BaseId baseId, required UserId userId, required MediaRef media, required Duration ttl, String? caption}` | Does **not** take a `Story` — `id`, `createdAt`, `syncStatus` are repository concerns.        |
/// | `streamActive`       | `Stream<List<Story>>` taking `BaseId`                                                                                            | The repository filters expired rows on every tick. Controllers never see expired stories.     |
/// | `listActive`         | `Future<Either<Failure, List<Story>>>` taking `BaseId`                                                                           | For the initial paint before the stream's first emission.                                     |
/// | `listArchive`        | `Future<Either<Failure, List<Story>>>` taking `BaseId`                                                                           | The "Highlights" surface.                                                                     |
/// | `deleteStory`        | `Future<Either<Failure, Unit>>` taking `StoryId`                                                                                 | Use `Unit` from `package:moonbase_skeleton/core/either.dart`, **not** `void`.                 |
/// | `expireAndArchive`   | `Future<Either<Failure, Unit>>` taking `BaseId`                                                                                  | Sweep job. Archives expired rows when `storiesArchiveEnabled`; else hard-deletes + `MediaStorage.delete`. |
///
/// Three subtle but important choices to internalise (first-steps guide
/// Section 6):
///
/// 1. **No `Story` instance gets passed in.** The use case hands the repo
///    the *content*; the repo produces the *entity*. Same shape as
///    `ChatRepository.sendMessage` taking `content`, not a `Message`.
/// 2. **`Stream<List<Story>>` is the source of truth, not the `Future`.**
///    Controllers subscribe to the stream; the `Future`-returning
///    `listActive` is only for the initial paint.
/// 3. **`Unit` instead of `void`.** `Either<Failure, void>` makes pattern
///    matching awkward; `Either<Failure, Unit>` is type-safe.
abstract class StoryRepository {
  Future<Either<Failure, Story>> publishStory({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    required BaseSettings settings,
    required String? caption,
  });

  Stream<List<Story>> streamActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listArchive(BaseId baseID);
  Future<Either<Failure, Unit>> deleteStory(StoryId storyId); // -> should this be UserId? story ID currently not initialized in the class
  Future<Either<Failure, Unit>> expiredAndArchive(BaseId baseId);

  
  // TODO(stories Step 4): declare the six abstract methods listed above.
  // For each load-bearing method (`streamActive`, `expireAndArchive`), add
  // a `///` doc-comment that captures the rule. Mirror the doc-comment
  // density used in `ChatRepository.streamMessages`.

  // TODO(stories Step 4): **DO NOT** add `Future<Story?> getStory(StoryId)`.
  // The DoD has no use case that needs it. YAGNI applies.
}
