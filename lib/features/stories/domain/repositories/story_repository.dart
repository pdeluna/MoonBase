// am i missing functions? will look over during testing for missing functionality or data
// nope you got all 6, just some clarifications i included here

// Going with an mtg analogy think of this file as oracle text (database for all things stories), not a card. 
//StoryRepository is an *abstract class* (the port) a list of promises (you can publish a story, stream the active ones, sweep the expired ones) 
// with no implementation behind them. It says WHAT can be done and never HOW. 
// The "how" — the actual Firestore calls — lives in a StoryRepositoryImpl over in the data layer.
// Remember the fetchland analogy from the provider file? This is the piece that makes it
// make sense. The abstract class here is the oracle text; the Impl is the printing
// that actually resolves; provider is the fetchland that goes and puts the real
// printing into play before the (app) starts. The domain only ever reads the
// oracle text (this repository file). it never knows or cares which printing it got (Firestore, a fake, an
// in-memory test double). That's the entire job of a port: swap the printing, the rules text is unchanged.
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
//import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
//import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
//import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
//import 'package:video_player/video_player.dart'; domain layer should never include plugins (purely dart)


abstract class StoryRepository { // abstract keyword: check junior notes (soon to be uploaded)
  Future<Either<Failure, Story>> publishStory({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    required Duration ttl,
    //required BaseSettings settings,
    // Why base settings doesn't belong (that's my bad ahha):
    // The port (abstract StoryRepository) should ask for exactly the value the job needs, not the full container that
    // value happens to live in. publishStory needs ONE thing out of settings: how long the story lives -> duration.
    // Handing the repository all of BaseSettings is like handing a judge your entire deck box when they asked 
    // "what's your commander ability?" — now they have to dig through everything to find the one fact they needed.
    // - p

    String? caption, // made it not required see story.dart clarification
  });

  Stream<List<Story>> streamActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listArchive(BaseId baseID);
  Future<Either<Failure, Unit>> deleteStory(StoryId storyId);
  Future<Either<Failure, Unit>> expireAndArchive(BaseId baseId); // must match the provider definition: expiredAndArchive -> expireAndArchive - p
}
