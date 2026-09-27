import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_permissions.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/event_input_validation.dart';

class UpdateEventParams {
  const UpdateEventParams({
    required this.base,
    required this.requester,
    required this.existing,
    required this.window,
    required this.input,
  });

  final Base base;
  final UserId requester;
  final CalendarEvent existing;
  final CalendarWindow window;
  final EventInput input;
}

/// Author-or-owner may edit (the creation policy does not apply — U-1).
/// Returns the locally merged event; the live feed delivers the server copy.
class UpdateEvent implements UseCase<CalendarEvent, UpdateEventParams> {
  UpdateEvent(this.repo, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final CalendarRepository repo;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, CalendarEvent>> call(UpdateEventParams p) async {
    if (!canModifyEvent(event: p.existing, user: p.requester, base: p.base)) {
      return const Left(PermissionDeniedFailure(
        'Only the author or the base owner can edit this event.',
      ));
    }
    final input = p.input.normalized();
    final now = _now();
    final invalid = validateEventInput(input, window: p.window, today: now);
    if (invalid != null) return Left(invalid);

    final res = await repo.updateEvent(
      baseId: p.base.id,
      eventId: p.existing.id,
      input: input,
    );
    return res.map(
      (_) => p.existing.copyWith(
        title: input.title,
        startAt: input.startAt,
        endAt: input.endAt,
        clearEndAt: input.endAt == null,
        allDay: input.allDay,
        notes: input.notes,
        clearNotes: input.notes == null,
        updatedAt: now.toUtc(),
      ),
    );
  }
}
