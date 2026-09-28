import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/lunar_candy.dart';

/// Placeholder stories carousel. No images, names, taps, or data — a visual
/// slot for the later stories feature.
class StoriesStrip extends StatelessWidget {
  const StoriesStrip({super.key});

  static const stripKey = Key('calendar-stories-strip');
  static const bubbleCount = 6;
  static const bubbleSize = 64.0;
  static const ringWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final candy = LunarCandy.of(context);
    return Semantics(
      key: stripKey,
      label: 'Stories',
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: bubbleCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _Bubble(dashed: i == 0, candy: candy),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.dashed, required this.candy});

  final bool dashed;
  final LunarCandy candy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (dashed)
          CustomPaint(
            painter: const _DashedCirclePainter(LunarCandy.accent),
            child: SizedBox(
              width: StoriesStrip.bubbleSize,
              height: StoriesStrip.bubbleSize,
              child: Icon(Icons.add, color: candy.ink),
            ),
          )
        else
          SizedBox(
            width: StoriesStrip.bubbleSize,
            height: StoriesStrip.bubbleSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: candy.cell,
                border: Border.all(
                  color: LunarCandy.accent,
                  width: StoriesStrip.ringWidth,
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: 36,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LunarCandy.accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = StoriesStrip.ringWidth
          ..strokeCap = StrokeCap.round;
    const inset = StoriesStrip.ringWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - StoriesStrip.ringWidth,
      size.height - StoriesStrip.ringWidth,
    );
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      const dash = 5.0;
      const gap = 4.0;
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
