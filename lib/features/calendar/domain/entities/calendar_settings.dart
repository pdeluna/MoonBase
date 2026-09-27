import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';

/// Per-base calendar settings (`bases/{baseId}/settings/calendar`).
///
/// [defaults] is the **one** defaults constant: the codec returns it when the
/// settings doc is missing, the rules `eventCreationPolicy()` returns
/// `'members'` for the same case, and the emulator + codec tests pin both.
class CalendarSettings {
  const CalendarSettings({required this.window, required this.eventCreation});

  static const defaults = CalendarSettings(
    window: CalendarWindow.defaults,
    eventCreation: EventCreationPolicy.allMembers,
  );

  final CalendarWindow window;
  final EventCreationPolicy eventCreation;

  /// Pure creation-policy check. UI uses it for FAB visibility; `CreateEvent`
  /// re-checks it; rules enforce `mayCreateEvent()` independently.
  bool canCreate({required UserId user, required Base base}) {
    switch (eventCreation) {
      case EventCreationPolicy.allMembers:
        return true;
      case EventCreationPolicy.ownerOnly:
        return base.ownerUserId == user;
    }
  }

  CalendarSettings copyWith({
    CalendarWindow? window,
    EventCreationPolicy? eventCreation,
  }) =>
      CalendarSettings(
        window: window ?? this.window,
        eventCreation: eventCreation ?? this.eventCreation,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarSettings &&
          other.window == window &&
          other.eventCreation == eventCreation);

  @override
  int get hashCode => Object.hash(window, eventCreation);

  @override
  String toString() =>
      'CalendarSettings(window: $window, eventCreation: $eventCreation)';
}
