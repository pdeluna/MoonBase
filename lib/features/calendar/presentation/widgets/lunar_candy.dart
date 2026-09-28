import 'package:flutter/material.dart';

/// Lunar Candy, painted on the stories strip and the calendar grid only.
///
/// Dark mode keeps the accent hues and takes canvas, cell, and ink from the
/// existing scheme — there is no second palette.
class LunarCandy {
  const LunarCandy({
    required this.canvas,
    required this.cell,
    required this.ink,
    required this.todayInk,
  });

  static const canvasLight = Color(0xFFF4F0FF);
  static const cellLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF2A2440);
  static const accent = Color(0xFF7C6BF2);
  static const today = Color(0xFFFF7AD9);
  static const pop = Color(0xFF5CE1C5);

  /// Extra-pop colors, cycled per event on a day. Lunar Candy ships one.
  static const dotColors = <Color>[pop];

  final Color canvas;
  final Color cell;
  final Color ink;

  /// Numeral on the solid today visor. The light-mode ink stays readable on
  /// [today] in both brightnesses.
  final Color todayInk;

  static LunarCandy of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      final scheme = theme.colorScheme;
      return LunarCandy(
        canvas: scheme.surface,
        cell: scheme.surfaceContainerHigh,
        ink: scheme.onSurface,
        todayInk: inkLight,
      );
    }
    return const LunarCandy(
      canvas: canvasLight,
      cell: cellLight,
      ink: inkLight,
      todayInk: inkLight,
    );
  }

  Color dotColor(int index) => dotColors[index % dotColors.length];
}
