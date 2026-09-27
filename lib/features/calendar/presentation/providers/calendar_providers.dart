import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/create_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/delete_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/get_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/set_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/update_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/watch_events.dart';

/// Override at app root with a concrete repo (`main.dart`).
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  throw UnimplementedError('Provide CalendarRepository in app wiring');
});

final watchEventsUseCaseProvider =
    Provider((ref) => WatchEvents(ref.read(calendarRepositoryProvider)));
final createEventUseCaseProvider =
    Provider((ref) => CreateEvent(ref.read(calendarRepositoryProvider)));
final updateEventUseCaseProvider =
    Provider((ref) => UpdateEvent(ref.read(calendarRepositoryProvider)));
final deleteEventUseCaseProvider =
    Provider((ref) => DeleteEvent(ref.read(calendarRepositoryProvider)));
final getCalendarSettingsUseCaseProvider = Provider(
    (ref) => GetCalendarSettings(ref.read(calendarRepositoryProvider)));
final setCalendarSettingsUseCaseProvider = Provider(
    (ref) => SetCalendarSettings(ref.read(calendarRepositoryProvider)));
