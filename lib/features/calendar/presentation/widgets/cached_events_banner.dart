import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';

/// Delayed non-blocking hint that the visible agenda is from the device
/// cache. Same posture and styling as chat's `CachedMessagesBanner` (R5),
/// kept in the calendar feature so the two features stay independent.
///
/// Hidden while [freshness] is not [CalendarFreshness.cached], and while the
/// feed is empty — cold-cache `count=0` is not "events saved on this device".
class CachedEventsBanner extends StatefulWidget {
  const CachedEventsBanner({
    super.key,
    required this.freshness,
    required this.hasEvents,
  });

  static const delay = Duration(milliseconds: 400);
  static const copy = 'Showing events saved on this device.';

  final CalendarFreshness? freshness;
  final bool hasEvents;

  @override
  State<CachedEventsBanner> createState() => _CachedEventsBannerState();
}

class _CachedEventsBannerState extends State<CachedEventsBanner> {
  Timer? _timer;
  bool _visible = false;

  bool get _shouldArm =>
      widget.freshness == CalendarFreshness.cached && widget.hasEvents;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CachedEventsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.freshness != widget.freshness ||
        oldWidget.hasEvents != widget.hasEvents) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_shouldArm) {
      _timer = Timer(CachedEventsBanner.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    } else if (_visible) {
      setState(() => _visible = false);
    } else {
      _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                color: scheme.onSecondaryContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                CachedEventsBanner.copy,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
