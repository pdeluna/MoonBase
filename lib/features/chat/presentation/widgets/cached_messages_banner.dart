import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';

/// Delayed non-blocking hint that the visible thread is from the device cache.
///
/// Hidden while [freshness] is not [ChatFreshness.cached], and while the
/// list is empty — cold-cache `count=0` is not "messages saved on this device".
class CachedMessagesBanner extends StatefulWidget {
  const CachedMessagesBanner({
    super.key,
    required this.freshness,
    required this.hasMessages,
  });

  /// Time after a non-empty cached feed before the bar appears.
  static const delay = Duration(milliseconds: 400);

  static const copy = 'Showing messages saved on this device.';

  final ChatFreshness? freshness;
  final bool hasMessages;

  @override
  State<CachedMessagesBanner> createState() => _CachedMessagesBannerState();
}

class _CachedMessagesBannerState extends State<CachedMessagesBanner> {
  Timer? _timer;
  bool _visible = false;

  bool get _shouldArm =>
      widget.freshness == ChatFreshness.cached && widget.hasMessages;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CachedMessagesBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.freshness != widget.freshness ||
        oldWidget.hasMessages != widget.hasMessages) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_shouldArm) {
      _timer = Timer(CachedMessagesBanner.delay, () {
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
            Icon(
              Icons.cloud_off_outlined,
              color: scheme.onSecondaryContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                CachedMessagesBanner.copy,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
