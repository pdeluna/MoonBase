import 'dart:async';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';

/// Wraps every data-source call in `guard*`; maps batches to `CalendarFeed`.
///
/// - `getSettings`: `guardWithTimeout` (get-only, `kGuardTimeout`).
/// - writes (`create/update/delete/setSettings`): `guard` / `guardVoid`,
///   unbounded — R3 posture, no write-sized timeout constant exists yet.
/// - `watchEvents`: stream errors are mapped through `mapException` so the
///   controller receives typed `Failure`s, never raw SDK exceptions.
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({required this.source});

  final CalendarDataSource source;

  @override
  Stream<CalendarFeed> watchEvents({
    required BaseId baseId,
    required CalendarDateRange range,
  }) =>
      source
          .watchEvents(
            baseId: baseId.value,
            fromUtc: range.from,
            toExclusiveUtc: range.toExclusive,
          )
          .map(
            (batch) => CalendarFeed(
              events: batch.events.map((m) => m.toEntity()).toList(),
              freshness: batch.fromCache
                  ? CalendarFreshness.cached
                  : CalendarFreshness.live,
            ),
          )
          .transform(
            StreamTransformer<CalendarFeed, CalendarFeed>.fromHandlers(
              handleError: (error, stackTrace, sink) =>
                  sink.addError(mapException(error), stackTrace),
            ),
          );

  @override
  Future<Either<Failure, CalendarEvent>> createEvent({
    required BaseId baseId,
    required UserId createdBy,
    required EventInput input,
  }) =>
      guard(() async {
        final m = await source.createEvent(
          baseId: baseId.value,
          createdBy: createdBy.value,
          input: input,
        );
        return m.toEntity();
      });

  @override
  Future<Either<Failure, void>> updateEvent({
    required BaseId baseId,
    required EventId eventId,
    required EventInput input,
  }) =>
      guardVoid(() => source.updateEvent(
            baseId: baseId.value,
            eventId: eventId.value,
            input: input,
          ));

  @override
  Future<Either<Failure, void>> deleteEvent({
    required BaseId baseId,
    required EventId eventId,
  }) =>
      guardVoid(() => source.deleteEvent(
            baseId: baseId.value,
            eventId: eventId.value,
          ));

  @override
  Future<Either<Failure, CalendarSettings>> getSettings({
    required BaseId baseId,
  }) =>
      guardWithTimeout(() => source.getSettings(baseId: baseId.value));

  @override
  Future<Either<Failure, void>> setSettings({
    required BaseId baseId,
    required CalendarSettings settings,
  }) =>
      guardVoid(() => source.setSettings(
            baseId: baseId.value,
            settings: settings,
          ));
}
