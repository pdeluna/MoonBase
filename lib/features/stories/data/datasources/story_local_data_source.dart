import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/data/models/story_model.dart';

/// Dumb per-base store. String ids. No expiry filter — the repo does that.
///
/// publishStory assigns id, createdAt, and syncStatus: synced.
/// streamStories / listStories return every row for that base.
/// deleteStory looks up by story id (keep an id → baseId index).
/// writeStories replaces the list; the sweep uses it.
abstract class StoryLocalDataSource {
  Future<StoryModel> publishStory({
    required String baseId,
    required String authorUserId,
    required MediaRef media,
    required Duration ttl,
    String? caption,
  });

  Stream<List<StoryModel>> streamStories(String baseId);

  Future<List<StoryModel>> listStories(String baseId);

  Future<void> deleteStory(String storyId);

  /// Replace every stored row for [baseId]. The expiry sweep writes here.
  Future<void> writeStories(String baseId, List<StoryModel> rows);
}
