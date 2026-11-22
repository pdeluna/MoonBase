import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';

/// Missing doc ⇒ `CalendarSettings.defaults` (handled by the repository codec).
class GetCalendarSettings implements UseCase<CalendarSettings, BaseId> {
  const GetCalendarSettings(this.repo);

  final CalendarRepository repo;

  @override
  Future<Either<Failure, CalendarSettings>> call(BaseId baseId) =>
      repo.getSettings(baseId: baseId);
}
