// TODO(stories Step 5): uncomment these imports as you add the real fields
// and call body. Listed here for visibility and to keep the scaffold stub
// lint-clean.
//
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

/// Per-call parameters for `PublishStory`.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 7.
///
/// Mirror: `SendMessageParams` in
/// `lib/features/chat/domain/usecases/send_message.dart`.
///
/// Required fields (the caller — i.e. the controller — supplies these per
/// call; the *repository* is injected once on the use case itself):
///
/// - `BaseId baseId`
/// - `UserId authorUserId`
/// - `MediaRef media`
/// - `String? caption`
/// - `BaseSettings settings`  **(the controller reads current settings via
///   `BaseSettingsController` and passes them in; use cases never reach
///   across repositories.)**
class PublishStoryParams {
  const PublishStoryParams({required this.baseId, required this.authorUserId, required this.media, required this.settings, this.caption});
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final BaseSettings settings;
  final String? caption;

}

/// Use case: validate then publish a single story.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 7.
///
/// Mirror: `SendMessage` in
/// `lib/features/chat/domain/usecases/send_message.dart` — same constructor
/// shape, same `Either<Failure, T>` return convention, same "validate then
/// forward" idiom.
///
/// Required behaviour for `call(p)`:
///
/// 1. If `!p.settings.storiesEnabled`, return
///    `Left(ValidationFailure('Stories are disabled for this base.'))`.
/// 2. Trim the caption.
/// 3. If the trimmed caption length is greater than 280 characters, return
///    `Left(ValidationFailure('Caption must be 280 characters or fewer.'))`.
/// 4. Otherwise forward to
///    `repo.publishStory(baseId: ..., userId: ..., media: ..., ttl:
///    p.settings.storyTtl, caption: trimmed.isEmpty ? null : trimmed)`.
///    Return the result directly — no `match`, no wrapping.
///
/// Pitfalls (first-steps guide Section 7):
///
/// - **No `try`/`catch`.** Failures from the repository come back as
///   `Left(Failure)` because the repo wrapped its I/O with `guard(...)`.
///   A `try` here is a sign you're about to violate the project's
///   failure-handling rule.
/// - **Store the repo on the use case, not on the params.** The use case
///   has one collaborator (`StoryRepository`); inject in the constructor.
///   The params struct only holds what the *caller* provides per call.
///
/// Once this class compiles, write
/// `test/features/stories/domain/usecases/publish_story_test.dart`
/// (see scaffolded test file).
class PublishStory implements UseCase<Story, PublishStoryParams> {
  // TODO(stories Step 5): change the class signature to
  //   class PublishStory implements UseCase<Story, PublishStoryParams> {
  // once `Story` has the real fields and you have imports uncommented.

  // TODO(stories Step 5): replace this placeholder constructor with
  //   const PublishStory(this.repo);
  // and declare `final StoryRepository repo;` immediately below.
  const PublishStory(this.repo);
  final StoryRepository repo;

  @override
  Future<Either<Failure, Story>> call(PublishStoryParams p) async {
    if(!p.settings.storiesEnabled){
      return const Left(ValidationFailure('Stories are disabled for this base'));
    }
    const int maxCaptionSize = 280;
    final String? cap = p.caption?.trim();
    if(cap != null && cap.length > maxCaptionSize) { 
      return const Left(ValidationFailure('Caption must be 280 or fewer characters'));
    }
    
    
    return repo.publishStory(
      baseId: p.baseId,
      authorUserId: p.authorUserId, 
      media: p.media, 
      settings: p.settings, 
      ttl: p.settings.storyTtl,
      caption: (cap == null || cap.isEmpty) ? null : cap);
  }

