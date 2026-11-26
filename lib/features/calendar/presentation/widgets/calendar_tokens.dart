import 'package:flutter/material.dart';

/// Board colors for the Home calendar. Dark mode keeps [accent] and [memory]
/// and takes the surfaces and ink from the existing scheme.
class CalendarTokens {
  const CalendarTokens({
    required this.canvas,
    required this.card,
    required this.border,
    required this.ink,
    required this.secondary,
    required this.skeleton,
  });

  static const canvasLight = Color(0xFFF7F7F5);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE7E8E3);
  static const inkLight = Color(0xFF15171C);
  static const secondaryLight = Color(0xFF5C6270);
  static const skeletonLight = Color(0xFFE7E8E3);
  static const accent = Color(0xFF46518F);
  static const memory = Color(0xFFA1613A);

  final Color canvas;
  final Color card;
  final Color border;
  final Color ink;
  final Color secondary;
  final Color skeleton;

  static CalendarTokens of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      final scheme = theme.colorScheme;
      return CalendarTokens(
        canvas: scheme.surface,
        card: scheme.surfaceContainerHigh,
        border: scheme.outlineVariant,
        ink: scheme.onSurface,
        secondary: scheme.onSurfaceVariant,
        skeleton: scheme.surfaceContainerHighest,
      );
    }
    return const CalendarTokens(
      canvas: canvasLight,
      card: cardLight,
      border: borderLight,
      ink: inkLight,
      secondary: secondaryLight,
      skeleton: skeletonLight,
    );
  }

  /// TODAY / SHARED TODAY / ON THE CALENDAR.
  static TextStyle overline(BuildContext context) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
      color: of(context).secondary,
    );
  }
}
