import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/bases_unreachable_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/cached_events_banner.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/day_section.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/window_label.dart';

/// Home tab body. Owns all four no-base states (bug B-e) and the agenda.
///
/// Subscribes the controller to the selected base via `ref.listen` and an
/// initial post-frame load, mirroring `ChatScreen`; a base switch cancels the
/// previous feed inside the controller.
class CalendarHomeView extends ConsumerStatefulWidget {
  const CalendarHomeView({super.key});

  static const emptyWindowCopy = 'Nothing planned in this window';
  static const truncatedCopy =
      'This window has more than $kCalendarFeedLimit events — showing the first $kCalendarFeedLimit.';
  static const settingsUnavailableCopy =
      'Couldn\'t load calendar settings — showing the default window.';
  static const feedErrorCopy = 'Couldn\'t load events.';

  @override
  ConsumerState<CalendarHomeView> createState() => _CalendarHomeViewState();
}

class _CalendarHomeViewState extends ConsumerState<CalendarHomeView> {
  String? _loadedBaseId;

  void _syncController(Base? base) {
    final controller = ref.read(calendarControllerProvider.notifier);
    if (base == null) {
      if (_loadedBaseId != null) {
        _loadedBaseId = null;
        controller.clear();
      }
      return;
    }
    if (_loadedBaseId != base.id.value) {
      _loadedBaseId = base.id.value;
      controller.load(base.id.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Base?>(effectiveSelectedBaseProvider, (_, next) {
      _syncController(next);
    });
    final vm = ref.watch(calendarHomeVmProvider);

    // Initial load when the base is already selected on first build.
    final selected = vm.selectedBase;
    if (selected != null && _loadedBaseId != selected.id.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncController(ref.read(effectiveSelectedBaseProvider));
      });
    }

    switch (vm.basesState) {
      case CalendarBasesState.loading:
        return const CalendarLoadingSkeleton();
      case CalendarBasesState.unreachable:
        return BasesUnreachableView(
          onRetry: () => ref.invalidate(basesListProvider),
        );
      case CalendarBasesState.empty:
        return NoBaseView(hasBases: vm.hasBases);
      case CalendarBasesState.ready:
        return _Agenda(vm: vm);
    }
  }
}

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.vm});

  final CalendarHomeVM vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WindowLabel(
          window: vm.settings.window,
          isOwner: vm.isOwner,
          onOpenSettings: () => showCalendarSettings(context, ref),
        ),
        CachedEventsBanner(freshness: vm.freshness, hasEvents: vm.hasEvents),
        if (vm.settingsUnavailable)
          const _InfoStrip(text: CalendarHomeView.settingsUnavailableCopy),
        if (vm.isTruncated)
          const _InfoStrip(text: CalendarHomeView.truncatedCopy),
        Expanded(child: _AgendaBody(vm: vm)),
      ],
    );
  }
}

class _AgendaBody extends ConsumerWidget {
  const _AgendaBody({required this.vm});

  final CalendarHomeVM vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = vm.feedError;
    if (error != null) {
      return _FeedError(
        error: error,
        onRetry: () => ref.read(calendarControllerProvider.notifier).reload(),
      );
    }
    if (vm.isFeedLoading) return const CalendarLoadingSkeleton();
    if (!vm.hasEvents) {
      return _EmptyWindow(
        canAdd: vm.canAddEvent,
        onAdd: () => showEventEditor(context, ref),
      );
    }
    return _AgendaList(
      sections: vm.sections,
      onEventTap: (e) => showEventDetail(context, ref, e),
    );
  }
}

/// Today is the scroll anchor: past days live in a reversed sliver *before*
/// the [CustomScrollView.center], today + future after it, so the list opens
/// scrolled to today without measuring row heights.
class _AgendaList extends StatelessWidget {
  const _AgendaList({required this.sections, required this.onEventTap});

  static const centerKey = ValueKey<String>('calendar-today-anchor');

  final List<DaySection> sections;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final todayIndex = sections.indexWhere((s) => s.isToday);
    final splitAt = todayIndex < 0 ? 0 : todayIndex;
    final past = sections.sublist(0, splitAt);
    final todayAndFuture = sections.sublist(splitAt);

    return CustomScrollView(
      center: centerKey,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final section = past[past.length - 1 - i];
              return DaySectionTile(
                key: ValueKey(section.day),
                section: section,
                onEventTap: onEventTap,
              );
            },
            childCount: past.length,
          ),
        ),
        SliverList(
          key: centerKey,
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final section = todayAndFuture[i];
              return DaySectionTile(
                key: ValueKey(section.day),
                section: section,
                onEventTap: onEventTap,
              );
            },
            childCount: todayAndFuture.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
      ],
    );
  }
}

class _EmptyWindow extends StatelessWidget {
  const _EmptyWindow({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              CalendarHomeView.emptyWindowCopy,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (canAdd) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add event'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final err = error;
    final detail = err is Failure ? err.message : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              CalendarHomeView.feedErrorCopy,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 20, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
