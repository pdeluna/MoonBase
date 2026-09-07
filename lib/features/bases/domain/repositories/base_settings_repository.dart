import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';

/// Per-base knobs (TTL, archive on/off, stories enabled).
///
/// Port only this week. StoryRepositoryImpl needs get for the sweep.
/// Owner settings screen is not this file.
abstract class BaseSettingsRepository {
  Future<Either<Failure, BaseSettings>> get(BaseId baseId);

  Future<Either<Failure, BaseSettings>> update(BaseSettings settings);
}
