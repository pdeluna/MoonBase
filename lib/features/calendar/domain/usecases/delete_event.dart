import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_permissions.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';

class DeleteEventParams {
  const DeleteEventParams({
    required this.base,
    required this.requester,
    required this.event,
  });

  final Base base;
  final UserId requester;
  final CalendarEvent event;
}

/// Author-or-owner may delete.
class DeleteEvent implements UseCase<void, DeleteEventParams> {
  const DeleteEvent(this.repo);

  final CalendarRepository repo;

  @override
  Future<Either<Failure, void>> call(DeleteEventParams p) async {
    if (!canModifyEvent(event: p.event, user: p.requester, base: p.base)) {
      return const Left(PermissionDeniedFailure(
        'Only the author or the base owner can delete this event.',
      ));
    }
    return repo.deleteEvent(baseId: p.base.id, eventId: p.event.id);
  }
}
