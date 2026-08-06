
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

//class initialization
class PublishStoryParams {
  const PublishStoryParams({required this.baseId, required this.authorUserId, required this.media, required this.settings, this.caption});
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final BaseSettings settings;
  final String? caption;

}

class PublishStory implements UseCase<Story, PublishStoryParams> { // implements keyword (check junior notes and diagrams soon to be uploaded)

  const PublishStory(this.repo);
  final StoryRepository repo; // repo variable refers to the current instance of 'StoryRepository'

// next function checks 2 things before story is pushed to publish return value.
// first is if the base allows for stories to be posted.
// second is if the caption length adheres to the limit of 280 characters or less.
  @override
  Future<Either<Failure, Story>> call(PublishStoryParams p) async { // junior reminder: 'p' refers to the current variable/instance of the story being checked
  // why does the function use async? acts as a place holder for the future function until it returns a value or an error
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
      ttl: p.settings.storyTtl, //implementation asks for ttl to be present. must find a place to properly define before return call
      caption: (cap == null || cap.isEmpty) ? null : cap);
  }}

