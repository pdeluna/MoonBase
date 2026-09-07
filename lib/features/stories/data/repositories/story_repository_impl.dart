import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_settings_repository.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/stories/data/datasources/story_local_data_source.dart';
import 'package:moonbase_skeleton/features/stories/data/datasources/story_remote_data_source.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

/// Phase 3 adapter: local + MediaStorage + BaseSettingsRepository.
///
/// Each mutation: guard(() async { ... }) then model.toEntity().
/// streamActive / listActive drop expired and archived rows.
/// expireAndArchive: settings.storiesArchiveEnabled → archive vs media.delete.
/// remote is null this phase — do not call it.
class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl({
    required this.local,
    required this.media,
    required this.settings,
    this.remote,
  });

  final StoryLocalDataSource local;
  final StoryRemoteDataSource? remote;
  final MediaStorage media;
  final BaseSettingsRepository settings;

  String get _wired =>
      '${local.runtimeType}|${remote.runtimeType}|${media.runtimeType}|${settings.runtimeType}';

  @override
  Future<Either<Failure, Story>> publishStory({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    required Duration ttl,
    String? caption,
  }) {
    // local.publishStory → toEntity. Then run the expiry sweep for this base.
    throw UnimplementedError(_wired);
  }

  @override
  Stream<List<Story>> streamActive(BaseId baseId) {
    // local.streamStories → toEntity → drop isExpired || archived.
    throw UnimplementedError(_wired);
  }

  @override
  Future<Either<Failure, List<Story>>> listActive(BaseId baseId) {
    // Same filter as streamActive.
    throw UnimplementedError(_wired);
  }

  @override
  Future<Either<Failure, List<Story>>> listArchive(BaseId baseID) {
    // Archived rows only. Do not apply the active-feed expiry filter.
    throw UnimplementedError(_wired);
  }

  @override
  Future<Either<Failure, Unit>> deleteStory(StoryId storyId) {
    throw UnimplementedError(_wired);
  }

  @override
  Future<Either<Failure, Unit>> expireAndArchive(BaseId baseId) {
    // settings.get(baseId), then archive or media.delete + writeStories.
    throw UnimplementedError(_wired);
  }
}
