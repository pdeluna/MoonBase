import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_settings_dialog.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_detail_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_editor_sheet.dart';

/// Entry points shared by the Home FAB, the empty state, and the detail
/// sheet. Each reads the VM at call time, routes the intent to the
/// controller, and lets the sheet/dialog render the returned `Failure`.
///
/// Presenter adoption (W3 `showFailureSnackBar` / `userMessage`) replaces the
/// `failure.message` snackbars here once `feat/failure-presenter` merges.

Future<void> showEventEditor(
  BuildContext context,
  WidgetRef ref, {
  CalendarEvent? existing,
}) {
  final vm = ref.read(calendarHomeVmProvider);
  final base = vm.selectedBase;
  final user = vm.currentUser;
  if (base == null || user == null) return Future.value();
  final today = ref.read(calendarClockProvider)();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EventEditorSheet(
      window: vm.settings.window,
      today: today,
      existing: existing,
      onSubmit: (EventInput input) {
        final c = ref.read(calendarControllerProvider.notifier);
        return existing == null
            ? c.create(base: base, requester: user.id, input: input)
            : c.update(
                base: base,
                requester: user.id,
                existing: existing,
                input: input,
              );
      },
    ),
  );
}

Future<void> showEventDetail(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) {
  final vm = ref.read(calendarHomeVmProvider);
  final member = ref.read(memberPresentationProvider(event.createdBy.value));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => EventDetailSheet(
      event: event,
      authorNickname: member.nickname,
      authorColor: member.nameColor,
      canModify: vm.canModify(event),
      onEdit: () {
        Navigator.of(sheetContext).pop();
        showEventEditor(context, ref, existing: event);
      },
      onDelete: () async {
        Navigator.of(sheetContext).pop();
        await confirmAndDeleteEvent(context, ref, event);
      },
    ),
  );
}

Future<void> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete event?'),
      content:
          Text('"${event.title}" will be removed for everyone in this base.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final vm = ref.read(calendarHomeVmProvider);
  final base = vm.selectedBase;
  final user = vm.currentUser;
  if (base == null || user == null) return;
  final failure = await ref
      .read(calendarControllerProvider.notifier)
      .delete(base: base, requester: user.id, event: event);
  if (failure != null && context.mounted) showCalendarFailure(context, failure);
}

Future<void> showCalendarSettings(BuildContext context, WidgetRef ref) {
  final vm = ref.read(calendarHomeVmProvider);
  final base = vm.selectedBase;
  final user = vm.currentUser;
  if (base == null || user == null || !vm.isOwner) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (_) => CalendarSettingsDialog(
      initial: vm.settings,
      onSubmit: (CalendarSettings s) => ref
          .read(calendarControllerProvider.notifier)
          .saveSettings(base: base, requester: user.id, settings: s),
    ),
  );
}

void showCalendarFailure(BuildContext context, Failure failure) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(failure.message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

/// FAB visibility for the Home shell: ready base + creation policy allows.
bool canShowAddEventFab(CalendarHomeVM vm) =>
    vm.basesState == CalendarBasesState.ready && vm.canAddEvent;
