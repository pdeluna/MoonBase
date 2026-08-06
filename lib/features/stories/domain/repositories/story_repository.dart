// am i missing functions? will look over during testing for missing functionality or data
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
import 'package:video_player/video_player.dart';


abstract class StoryRepository { // abstract keyword: check junior notes (soon to be uploaded)
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
  Future<Either<Failure, Unit>> deleteStory(StoryId storyId);
  Future<Either<Failure, Unit>> expiredAndArchive(BaseId baseId);
}
