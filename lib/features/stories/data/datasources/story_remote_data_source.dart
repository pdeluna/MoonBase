import 'package:moonbase_skeleton/features/stories/data/datasources/story_local_data_source.dart';

/// Phase 4 placeholder. Same surface as [StoryLocalDataSource].
///
/// Leave unimplemented. StoryRepositoryImpl.remote stays null in Phase 3.
/// Endpoints: blueprint §4.3.
abstract class StoryRemoteDataSource implements StoryLocalDataSource {
  const StoryRemoteDataSource();
}
