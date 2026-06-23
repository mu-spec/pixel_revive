import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF090A0F); // Pitch Black / Dark Slate
  static const Color accent = Color(0xFF6366F1); // Sleek Indigo
  static const Color accentLight = Color(0xFF93C5FD); // Ice Blue
  static const Color surface = Color(0xFF11131E); // Elevated premium surface
  static const Color card = Color(0xFF1E2132); // Container background
  static const Color text = Color(0xFFFFFFFF); // Clean white
  static const Color textMuted = Color(0xFF8E93B2); // Lavender Gray
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color gold = Color(0xFFF59E0B); // Amber Yellow
  
  // Custom Gradients
  static const List<Color> brandGradient = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink Rose
  ];

  static const List<Color> goldGradient = [
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Crimson Red
  ];
}