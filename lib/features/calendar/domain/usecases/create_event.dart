import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/event_input_validation.dart';

class CreateEventParams {
  const CreateEventParams({
    required this.base,
    required this.requester,
    required this.settings,
    required this.input,
  });

  final Base base;
  final UserId requester;

  /// The settings the controller is currently showing. Rules re-read the
  /// server copy on create, so a stale client copy can only be *more*
  /// permissive than reality — the write is then rule-denied and surfaces as
  /// a `Failure`, never as a silent success.
  final CalendarSettings settings;
  final EventInput input;
}

/// Validates the payload, applies the creation policy, forwards to the repo.
///
/// No `try`/`catch`: the repository already returns `Left(Failure)` via
/// `guard(...)`.
class CreateEvent implements UseCase<CalendarEvent, CreateEventParams> {
  CreateEvent(this.repo, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final CalendarRepository repo;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, CalendarEvent>> call(CreateEventParams p) async {
    if (!p.settings.canCreate(user: p.requester, base: p.base)) {
      return const Left(PermissionDeniedFailure(
        'Only the base owner can add events here.',
      ));
    }
    final input = p.input.normalized();
    final invalid = validateEventInput(
      input,
      window: p.settings.window,
      today: _now(),
    );
    if (invalid != null) return Left(invalid);

    return repo.createEvent(
      baseId: p.base.id,
      createdBy: p.requester,
      input: input,
    );
  }
}
