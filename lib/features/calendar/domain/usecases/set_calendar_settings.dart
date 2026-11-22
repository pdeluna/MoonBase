import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';

class SetCalendarSettingsParams {
  const SetCalendarSettingsParams({
    required this.base,
    required this.requester,
    required this.settings,
  });

  final Base base;
  final UserId requester;
  final CalendarSettings settings;
}

/// Owner-only; clamps the window to `0..kCalendarWindowMaxDays`. Returns the
/// settings actually written so the caller can adopt the clamped values.
class SetCalendarSettings
    implements UseCase<CalendarSettings, SetCalendarSettingsParams> {
  const SetCalendarSettings(this.repo);

  final CalendarRepository repo;

  @override
  Future<Either<Failure, CalendarSettings>> call(
    SetCalendarSettingsParams p,
  ) async {
    if (p.base.ownerUserId != p.requester) {
      return const Left(PermissionDeniedFailure(
        'Only the base owner can change calendar settings.',
      ));
    }
    final clamped = p.settings.copyWith(window: p.settings.window.clamp());
    final res = await repo.setSettings(baseId: p.base.id, settings: clamped);
    return res.map((_) => clamped);
  }
}
