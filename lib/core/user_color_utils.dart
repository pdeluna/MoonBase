import 'dart:math';
import 'package:flutter/material.dart';

class UserColorUtils {
  // Predefined colors that work well for text and are visually distinct
  static const List<Color> _predefinedColors = [
    Color(0xFFE74C3C), // Red
    Color(0xFF3498DB), // Blue
    Color(0xFF2ECC71), // Green
    Color(0xFFF39C12), // Orange
    Color(0xFF9B59B6), // Purple
    Color(0xFF1ABC9C), // Teal
    Color(0xFFE67E22), // Dark Orange
    Color(0xFF34495E), // Dark Blue
    Color(0xFF16A085), // Dark Teal
    Color(0xFF8E44AD), // Dark Purple
    Color(0xFFD35400), // Dark Orange
    Color(0xFFC0392B), // Dark Red
    Color(0xFF2980B9), // Dark Blue
    Color(0xFF27AE60), // Dark Green
    Color(0xFFF1C40F), // Yellow
  ];

  /// Generate a consistent color for a user based on their user ID
  static Color getColorForUserId(String userId) {
    // Use the hash code of the user ID to ensure consistent colors
    final hash = userId.hashCode;
    final random = Random(hash);
    
    // Pick a random color from our predefined palette
    final colorIndex = random.nextInt(_predefinedColors.length);
    return _predefinedColors[colorIndex];
  }

  /// Generate a color that contrasts well with the background
  static Color getContrastingColor(Color backgroundColor) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Get a slightly lighter version of a color for hover states
  static Color getLighterColor(Color color) {
    return color.withValues(alpha: 0.8);
  }

  /// Get a slightly darker version of a color for pressed states
  static Color getDarkerColor(Color color) {
    return color.withValues(alpha: 0.6);
  }

  /// Get a color that's visually distinct from the given color
  static Color getDistinctColor(Color baseColor) {
    // Find a color that's significantly different from the base color
    Color bestColor = _predefinedColors.first;
    double maxDifference = 0.0;
    
    for (final color in _predefinedColors) {
      final difference = _calculateColorDifference(baseColor, color);
      if (difference > maxDifference) {
        maxDifference = difference;
        bestColor = color;
      }
    }
    
    return bestColor;
  }

  /// Calculate the perceptual difference between two colors
  static double _calculateColorDifference(Color color1, Color color2) {
    // Simple Euclidean distance in RGB space
    final rDiff = (color1.r * 255).round() - (color2.r * 255).round();
    final gDiff = (color1.g * 255).round() - (color2.g * 255).round();
    final bDiff = (color1.b * 255).round() - (color2.b * 255).round();
    
    return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);
  }
}
