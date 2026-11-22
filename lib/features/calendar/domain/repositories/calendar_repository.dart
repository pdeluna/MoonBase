import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Calendar port — no Firebase types.
///
/// Speaks in UTC ranges and `Either`; a Postgres/REST adapter would map to
/// `events(base_id, start_at, …)` and `base_settings(base_id, kind)`.
/// Permission checks (creation policy, author-or-owner) live in the use
/// cases, not here; the adapter's backend enforces them independently.
abstract class CalendarRepository {
  /// Live feed of events whose `startAt` falls inside [range]. Errors are
  /// delivered on the stream as typed `Failure`s.
  Stream<CalendarFeed> watchEvents({
    required BaseId baseId,
    required CalendarDateRange range,
  });

  Future<Either<Failure, CalendarEvent>> createEvent({
    required BaseId baseId,
    required UserId createdBy,
    required EventInput input,
  });

  /// Write-only: the live feed delivers the updated document.
  Future<Either<Failure, void>> updateEvent({
    required BaseId baseId,
    required EventId eventId,
    required EventInput input,
  });

  Future<Either<Failure, void>> deleteEvent({
    required BaseId baseId,
    required EventId eventId,
  });

  /// Missing settings doc ⇒ `CalendarSettings.defaults` (get-only; bounded).
  Future<Either<Failure, CalendarSettings>> getSettings({
    required BaseId baseId,
  });

  /// Whole-document write (unbounded — R3 posture, no write timeout).
  Future<Either<Failure, void>> setSettings({
    required BaseId baseId,
    required CalendarSettings settings,
  });
}
