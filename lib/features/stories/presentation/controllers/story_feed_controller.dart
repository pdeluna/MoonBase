import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_role.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/delete_story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/expire_and_archive.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_active_stories.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/list_archive.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/stream_active_stories.dart';
import 'package:moonbase_skeleton/features/stories/presentation/providers/story_providers.dart';

class StoryFeedState {
  const StoryFeedState({
    this.active = const AsyncValue.data(<Story>[]),
    this.archive = const AsyncValue.data(<Story>[]),
    this.publishing = const AsyncValue<void>.data(null),
  });

  final AsyncValue<List<Story>> active;
  final AsyncValue<List<Story>> archive;
  final AsyncValue<void> publishing;

  StoryFeedState copyWith({
    AsyncValue<List<Story>>? active,
    AsyncValue<List<Story>>? archive,
    AsyncValue<void>? publishing,
  }) {
    return StoryFeedState(
      active: active ?? this.active,
      archive: archive ?? this.archive,
      publishing: publishing ?? this.publishing,
    );
  }
}

/// Owns AsyncValue lists for the feed. Widgets are not this file.
///
/// load: cancel any prior sub, ListActiveStories + ListArchive, then
/// subscribe to StreamActiveStories (ticks replace active).
/// publish: pass BaseSettings in; res.match at this boundary.
/// delete: pass authorUserId + actingRole from the caller.
/// Always _sub?.cancel() in dispose.
class StoryFeedController extends StateNotifier<StoryFeedState> {
  StoryFeedController({
    required ListActiveStories listActive,
    required ListArchive listArchive,
    required StreamActiveStories streamActive,
    required PublishStory publishStory,
    required DeleteStory deleteStory,
    required ExpireAndArchiveStories expireAndArchive,
  })  : _listActive = listActive,
        _listArchive = listArchive,
        _streamActive = streamActive,
        _publishStory = publishStory,
        _deleteStory = deleteStory,
        _expireAndArchive = expireAndArchive,
        super(const StoryFeedState());

  final ListActiveStories _listActive;
  final ListArchive _listArchive;
  final StreamActiveStories _streamActive;
  final PublishStory _publishStory;
  final DeleteStory _deleteStory;
  final ExpireAndArchiveStories _expireAndArchive;

  List<Object> get _useCases => [
        _listActive,
        _listArchive,
        _streamActive,
        _publishStory,
        _deleteStory,
        _expireAndArchive,
      ];

  Future<void> load(BaseId baseId) async {
    throw UnimplementedError('load $baseId ${_useCases.length}');
  }

  Future<void> publish({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    required BaseSettings settings,
    String? caption,
  }) async {
    throw UnimplementedError(
      'publish $baseId $authorUserId $media $settings $caption ${_useCases.length}',
    );
  }

  Future<void> delete({
    required StoryId id,
    required UserId actingUserId,
    required UserId authorUserId,
    required BaseRole actingRole,
  }) async {
    throw UnimplementedError(
      'delete $id $actingUserId $authorUserId $actingRole ${_useCases.length}',
    );
  }

  Future<void> sweepExpired(BaseId baseId) async {
    throw UnimplementedError('sweep $baseId ${_useCases.length}');
  }
}

final storyFeedControllerProvider =
    StateNotifierProvider<StoryFeedController, StoryFeedState>((ref) {
  return StoryFeedController(
    listActive: ref.read(listActiveStoriesProvider),
    listArchive: ref.read(listArchiveProvider),
    streamActive: ref.read(streamActiveStoriesProvider),
    publishStory: ref.read(publishStoryProvider),
    deleteStory: ref.read(deleteStoryProvider),
    expireAndArchive: ref.read(expireAndArchiveStoriesProvider),
  );
});
