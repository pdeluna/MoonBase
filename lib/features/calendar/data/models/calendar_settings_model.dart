import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';

/// Codec for `bases/{baseId}/settings/calendar`.
///
/// The **only** place defaults are substituted is the missing-doc case
/// ([fromFirestore] with `null`), and it returns `CalendarSettings.defaults`
/// whole — never field-by-field merges. Wire values for the policy are
/// `'members'` / `'owner'` (rules `isValidEventCreation`).
class CalendarSettingsModel {
  const CalendarSettingsModel._();

  static const firestoreSchemaVersion = 1;
  static const docId = 'calendar';

  static const _policyToWire = <EventCreationPolicy, String>{
    EventCreationPolicy.allMembers: 'members',
    EventCreationPolicy.ownerOnly: 'owner',
  };

  static CalendarSettings fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return CalendarSettings.defaults;
    return CalendarSettings(
      window: CalendarWindow(
        pastDays: _int(data['pastDays'], CalendarWindow.defaults.pastDays),
        futureDays:
            _int(data['futureDays'], CalendarWindow.defaults.futureDays),
      ).clamp(),
      eventCreation: policyFromWire(data['eventCreation']),
    );
  }

  static Map<String, dynamic> toFirestore(CalendarSettings s) =>
      <String, dynamic>{
        'pastDays': s.window.pastDays,
        'futureDays': s.window.futureDays,
        'eventCreation': policyToWire(s.eventCreation),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': firestoreSchemaVersion,
      };

  static String policyToWire(EventCreationPolicy p) => _policyToWire[p]!;

  /// Unknown / missing wire value ⇒ the default policy (rules reject unknown
  /// values on write, so this only guards against a future third value read
  /// by an older client).
  static EventCreationPolicy policyFromWire(Object? raw) {
    for (final entry in _policyToWire.entries) {
      if (entry.value == raw) return entry.key;
    }
    return CalendarSettings.defaults.eventCreation;
  }
}

int _int(Object? raw, int fallback) => switch (raw) {
      int n => n,
      num n => n.toInt(),
      _ => fallback,
    };
