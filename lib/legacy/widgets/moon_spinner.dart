import 'dart:math' as math;
import 'package:flutter/material.dart';

class MoonSpinner extends StatefulWidget {
  const MoonSpinner({
    super.key,
    this.size = 48,
    this.orbit = 18,
    this.duration = const Duration(seconds: 1),
    this.assetPath, // e.g. 'assets/brand/moon.png'
  });

  /// Total square size of the spinner widget.
  final double size;
  /// Orbit radius for the moon's circular path.
  final double orbit;
  /// Full revolution duration.
  final Duration duration;
  /// Optional asset path for your moon logo (falls back to an icon if null).
  final String? assetPath;

  @override
  State<MoonSpinner> createState() => _MoonSpinnerState();
}

class _MoonSpinnerState extends State<MoonSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget moon;
    
    if (widget.assetPath != null) {
      moon = Image.asset(
        widget.assetPath!,
        width: 28,
        height: 28,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if asset fails to load
          return const Icon(Icons.nightlight_round, size: 14);
        },
      );
    } else {
      moon = const Icon(Icons.nightlight_round, size: 14);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final theta = 2 * math.pi * _c.value; // 0..2π
          final dx = widget.orbit * math.cos(theta);
          final dy = widget.orbit * math.sin(theta);

          return Stack(
            alignment: Alignment.center,
            children: [
              // moon traveling around center
              Transform.translate(
                offset: Offset(dx, dy),
                child: moon,
              ),
            ],
          );
        },
      ),
    );
  }
}
