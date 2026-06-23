import 'package:flutter/material.dart';

/// Small composite used in grids: a placeholder surface stamped with a
/// centered play indicator and (optionally) a duration badge.
///
/// Phase 3 keeps thumbnails generative rather than pre-rendered (see
/// `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.5: "defer thumbnail to widget if too
/// costly"). The `child` slot lets callers paint a real first-frame
/// underneath when one is available (e.g. a future `MediaRef.thumbnailKey`),
/// while the chrome (play icon + scrim + duration pill) stays consistent.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    super.key,
    this.child,
    this.duration,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  /// Optional underlay (e.g. a poster `Image.file`).
  final Widget? child;

  /// Displayed in the bottom-right corner as `m:ss`.
  final Duration? duration;

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (child != null)
              child!
            else
              ColoredBox(color: cs.surfaceContainerHighest),
            const _PlayScrim(),
            if (duration != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: _DurationPill(duration: duration!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayScrim extends StatelessWidget {
  const _PlayScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final mm = duration.inMinutes.toString();
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$mm:$ss',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
