import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';

/// Author-or-owner rule for editing / deleting an event.
///
/// One pure function used by `UpdateEvent` / `DeleteEvent` (enforcement) and
/// by the Home VM (affordance visibility) so the two cannot drift. Rules
/// enforce the same predicate server-side (`isEventAuthor() || isOwner()`).
bool canModifyEvent({
  required CalendarEvent event,
  required UserId user,
  required Base base,
}) =>
    event.createdBy == user || base.ownerUserId == user;
