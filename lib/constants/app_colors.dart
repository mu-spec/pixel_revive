import 'package:flutter/material.dart';

class AppColors {
  // Modern premium dark theme
  static const Color primary = Color(0xFF070814);
  static const Color backgroundEnd = Color(0xFF101528);
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentLight = Color(0xFFA78BFA);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color rose = Color(0xFFEC4899);
  static const Color surface = Color(0xFF121827);
  static const Color card = Color(0xFF182033);
  static const Color glass = Color(0xB31B2438);
  static const Color stroke = Color(0x1FFFFFFF);
  static const Color text = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textSoft = Color(0xFFCBD5E1);
  static const Color success = Color(0xFF10B981);
  static const Color gold = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const List<Color> brandGradient = [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF22D3EE),
  ];

  static const List<Color> purpleGradient = [
    Color(0xFF7C3AED),
    Color(0xFF4F46E5),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static LinearGradient get appBackgroundGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, Color(0xFF0B1020), backgroundEnd],
      );

  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.075),
          Colors.white.withOpacity(0.025),
        ],
      );
}
