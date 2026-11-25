import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/stories_seam.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/bases_unreachable_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/cached_events_banner.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_grid.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/date_heading.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/day_agenda.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/shared_today_section.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/stories_heading.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/week_strip.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/window_label.dart';

/// Home tab body. Owns the no-base states (bug B-e), the date heading and
/// stories row, and the week/month grid. The span is ephemeral drawing
/// state — it does not write the window.
///
/// Subscribes the controller to the selected base via `ref.listen` and an
/// initial post-frame load, mirroring `ChatScreen`; a base switch cancels the
/// previous feed inside the controller.
class CalendarHomeView extends ConsumerStatefulWidget {
  const CalendarHomeView({super.key});

  static const storiesSlotKey = Key('calendar-stories-slot');
  static const truncatedCopy =
      'Too many events to show. Here are the first $kCalendarFeedLimit.';
  static const settingsUnavailableCopy =
      "Couldn't load calendar settings. Showing the usual days.";
  static const feedErrorCopy = 'Couldn\'t load events.';

  /// Soft fade. Height tracks the fade so month mode can fill the tab.
  static const spanDuration = Duration(milliseconds: 150);

  @override
  ConsumerState<CalendarHomeView> createState() => _CalendarHomeViewState();
}

class _CalendarHomeViewState extends ConsumerState<CalendarHomeView> {
  String? _loadedBaseId;
  CalendarDrawSpan _span = CalendarDrawSpan.week;

  /// Null follows today. Not persisted.
  DayKey? _selected;

  void _syncController(Base? base) {
    final controller = ref.read(calendarControllerProvider.notifier);
    if (base == null) {
      if (_loadedBaseId != null) {
        _loadedBaseId = null;
        _selected = null;
        controller.clear();
      }
      return;
    }
    if (_loadedBaseId != base.id.value) {
      _loadedBaseId = base.id.value;
      _selected = null;
      controller.load(base.id.value);
    }
  }

  void _toggleSpan() {
    setState(() {
      _span = _span == CalendarDrawSpan.week
          ? CalendarDrawSpan.month
          : CalendarDrawSpan.week;
      _selected = null;
    });
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
        return _ReadyBody(
          vm: vm,
          span: _span,
          selected: _selected ?? vm.todayKey,
          onToggleSpan: _toggleSpan,
          onSelectDay: (day) => setState(() => _selected = day),
        );
    }
  }
}

class _ReadyBody extends ConsumerWidget {
  const _ReadyBody({
    required this.vm,
    required this.span,
    required this.selected,
    required this.onToggleSpan,
    required this.onSelectDay,
  });

  final CalendarHomeVM vm;
  final CalendarDrawSpan span;
  final DayKey selected;
  final VoidCallback onToggleSpan;
  final ValueChanged<DayKey> onSelectDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : CalendarHomeView.spanDuration;
    final showStories = span == CalendarDrawSpan.week;
    final l10n = MaterialLocalizations.of(context);
    final days = gridDays(
      span: span,
      sections: vm.sections,
      today: vm.todayKey,
      firstDayOfWeekIndex: l10n.firstDayOfWeekIndex,
    );

    return ColoredBox(
      color: CalendarTokens.of(context).canvas,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateHeading(
              today: vm.todayKey,
              onShare: _onShare(ref, context),
            ),
            ExcludeSemantics(
              excluding: !showStories,
              child: ClipRect(
                child: AnimatedAlign(
                  key: CalendarHomeView.storiesSlotKey,
                  alignment: Alignment.topCenter,
                  heightFactor: showStories ? 1 : 0,
                  duration: duration,
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: showStories ? 1 : 0,
                    duration: duration,
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: !showStories,
                      child: const StoriesHeading(),
                    ),
                  ),
                ),
              ),
            ),
            CalendarGridHeader(
              span: span,
              today: vm.todayKey,
              onToggleSpan: onToggleSpan,
            ),
            CachedEventsBanner(
              freshness: vm.freshness,
              hasEvents: vm.hasEvents,
            ),
            if (vm.settingsUnavailable)
              const _InfoStrip(
                text: CalendarHomeView.settingsUnavailableCopy,
              ),
            if (vm.isTruncated)
              const _InfoStrip(text: CalendarHomeView.truncatedCopy),
            _body(context, ref, days),
            WindowLabel(
              window: vm.settings.window,
              isOwner: vm.isOwner,
              onOpenSettings: () => showCalendarSettings(context, ref),
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<CalendarGridDay> days,
  ) {
    final error = vm.feedError;
    if (error != null) {
      return SizedBox(
        height: 320,
        child: _FeedError(
          key: const ValueKey('calendar-feed-error'),
          error: error,
          onRetry: () => ref.read(calendarControllerProvider.notifier).reload(),
        ),
      );
    }
    // An empty block means "loaded, no events" — keep the skeleton until the
    // feed has emitted.
    if (vm.isFeedLoading) {
      return const SizedBox(
        height: 320,
        child: CalendarLoadingSkeleton(key: ValueKey('calendar-feed-loading')),
      );
    }
    final stories = ref.watch(storiesHeadingProvider).asData?.value;
    final tiles = stories?.tiles ?? const [];
    final agenda = DayAgenda(
      day: selected,
      isToday: selected == vm.todayKey,
      events: _eventsOn(vm, selected),
      canAdd: canAddEventOn(vm, selected),
      onEventTap: (event) => showEventDetail(context, ref, event),
      onAdd: () => showEventEditor(context, ref, initialDay: selected),
    );
    if (span == CalendarDrawSpan.month) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarGrid(
            days: days,
            selected: selected,
            inWindow: (day) => isInWindow(vm, day),
            onSelectDay: onSelectDay,
          ),
          agenda,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekStrip(
          days: days,
          selected: selected,
          memoryDays: ref.watch(memoryDaysProvider),
          onSelect: onSelectDay,
        ),
        if (tiles.isNotEmpty)
          SharedTodaySection(tiles: tiles, keptUntil: stories?.keptUntil),
        agenda,
      ],
    );
  }
}

VoidCallback? _onShare(WidgetRef ref, BuildContext context) {
  final open = ref.watch(openStoryCaptureProvider);
  if (open == null) return null;
  return () => open(context);
}

List<CalendarEvent> _eventsOn(CalendarHomeVM vm, DayKey day) {
  for (final section in vm.sections) {
    if (section.day == day) return section.events;
  }
  return const [];
}

class _FeedError extends StatelessWidget {
  const _FeedError({super.key, required this.error, required this.onRetry});

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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
            Icon(
              Icons.info_outline,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
