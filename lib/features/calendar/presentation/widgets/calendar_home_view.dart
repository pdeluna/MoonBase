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
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/bases_unreachable_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/cached_events_banner.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_day_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_grid.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/lunar_candy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/stories_strip.dart';

/// Home tab body. Owns all four no-base states (bug B-e) and the week/month
/// grid. The span is ephemeral drawing state — it does not write the window.
///
/// Subscribes the controller to the selected base via `ref.listen` and an
/// initial post-frame load, mirroring `ChatScreen`; a base switch cancels the
/// previous feed inside the controller.
class CalendarHomeView extends ConsumerStatefulWidget {
  const CalendarHomeView({super.key});

  static const storiesSlotKey = Key('calendar-stories-slot');
  static const truncatedCopy =
      'This window has more than $kCalendarFeedLimit events — showing the first $kCalendarFeedLimit.';
  static const settingsUnavailableCopy =
      'Couldn\'t load calendar settings — showing the default window.';
  static const feedErrorCopy = 'Couldn\'t load events.';

  /// Soft fade. Height tracks the fade so month mode can fill the tab.
  static const spanDuration = Duration(milliseconds: 150);

  @override
  ConsumerState<CalendarHomeView> createState() => _CalendarHomeViewState();
}

class _CalendarHomeViewState extends ConsumerState<CalendarHomeView> {
  String? _loadedBaseId;
  CalendarDrawSpan _span = CalendarDrawSpan.week;

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

  void _toggleSpan() {
    setState(() {
      _span =
          _span == CalendarDrawSpan.week
              ? CalendarDrawSpan.month
              : CalendarDrawSpan.week;
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
        return _ReadyBody(vm: vm, span: _span, onToggleSpan: _toggleSpan);
    }
  }
}

class _ReadyBody extends ConsumerWidget {
  const _ReadyBody({
    required this.vm,
    required this.span,
    required this.onToggleSpan,
  });

  final CalendarHomeVM vm;
  final CalendarDrawSpan span;
  final VoidCallback onToggleSpan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candy = LunarCandy.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : CalendarHomeView.spanDuration;
    final showStories = span == CalendarDrawSpan.week;

    return ColoredBox(
      color: candy.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    child: const StoriesStrip(),
                  ),
                ),
              ),
            ),
          ),
          CalendarGridHeader(
            span: span,
            today: vm.todayKey,
            window: vm.settings.window,
            isOwner: vm.isOwner,
            onToggleSpan: onToggleSpan,
            onOpenSettings: () => showCalendarSettings(context, ref),
          ),
          CachedEventsBanner(freshness: vm.freshness, hasEvents: vm.hasEvents),
          if (vm.settingsUnavailable)
            const _InfoStrip(text: CalendarHomeView.settingsUnavailableCopy),
          if (vm.isTruncated)
            const _InfoStrip(text: CalendarHomeView.truncatedCopy),
          Expanded(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: _topAlignedStack,
              child: _gridArea(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridArea(BuildContext context, WidgetRef ref) {
    final error = vm.feedError;
    if (error != null) {
      return _FeedError(
        key: const ValueKey('calendar-feed-error'),
        error: error,
        onRetry: () => ref.read(calendarControllerProvider.notifier).reload(),
      );
    }
    // An empty block means "loaded, no events" — keep the skeleton until the
    // feed has emitted.
    if (vm.isFeedLoading) {
      return const CalendarLoadingSkeleton(
        key: ValueKey('calendar-feed-loading'),
      );
    }
    final l10n = MaterialLocalizations.of(context);
    final days = gridDays(
      span: span,
      sections: vm.sections,
      today: vm.todayKey,
      firstDayOfWeekIndex: l10n.firstDayOfWeekIndex,
    );
    return CalendarGrid(
      key: ValueKey(span),
      span: span,
      days: days,
      onDayTap: (day) => showCalendarDay(context, ref, day.events),
    );
  }
}

Widget _topAlignedStack(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    alignment: Alignment.topCenter,
    children: [...previousChildren, if (currentChild != null) currentChild],
  );
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
