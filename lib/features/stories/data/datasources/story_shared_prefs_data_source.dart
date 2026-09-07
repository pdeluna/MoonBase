import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/data/datasources/story_local_data_source.dart';
import 'package:moonbase_skeleton/features/stories/data/models/story_model.dart';

/// Local adapter. Key: `mb.stories.<baseId>`.
///
/// Pattern: ChatSharedPrefsDataSource — broadcast StreamController per base,
/// emit on every write. Do not filter expired rows here.
class StorySharedPrefsDataSource implements StoryLocalDataSource {
  StorySharedPrefsDataSource(this._prefs);

  final SharedPreferences _prefs;

  String _key(String baseId) => 'mb.stories.$baseId';

  @override
  Future<StoryModel> publishStory({
    required String baseId,
    required String authorUserId,
    required MediaRef media,
    required Duration ttl,
    String? caption,
  }) async {
    throw UnimplementedError(
        'persist ${_key(baseId)} via ${_prefs.runtimeType}');
  }

  @override
  Stream<List<StoryModel>> streamStories(String baseId) {
    throw UnimplementedError(
        'stream ${_key(baseId)} via ${_prefs.runtimeType}');
  }

  @override
  Future<List<StoryModel>> listStories(String baseId) async {
    throw UnimplementedError('list ${_key(baseId)} via ${_prefs.runtimeType}');
  }

  @override
  Future<void> deleteStory(String storyId) async {
    throw UnimplementedError('delete $storyId via ${_prefs.runtimeType}');
  }

  @override
  Future<void> writeStories(String baseId, List<StoryModel> rows) async {
    throw UnimplementedError(
        'write ${_key(baseId)} (${rows.length}) via ${_prefs.runtimeType}');
  }
}
