import 'package:flutter/material.dart';

class AppColors {
  // Primary Fox Colors
  static const Color primary = Color(0xFFFF6B35); // Fox Orange
  static const Color primaryLight = Color(0xFFFF8A5C);
  static const Color primaryDark = Color(0xFFE55A2B);

  // Secondary Colors
  static const Color secondary = Color(0xFF2D3047); // Dark Blue/Gray
  static const Color secondaryLight = Color(0xFF4A4E69);
  static const Color accent = Color(0xFFFFB347); // Light Orange/Gold

  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF252A34);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D3047);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textPrimaryDark = Color(0xFFF8F9FA);
  static const Color textSecondaryDark = Color(0xFFB0B8C4);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Category Colors
  static const Color electronics = Color(0xFF6366F1);
  static const Color vehicles = Color(0xFF14B8A6);
  static const Color properties = Color(0xFF8B5CF6);
  static const Color fashion = Color(0xFFEC4899);
  static const Color furniture = Color(0xFFF97316);
  static const Color jobs = Color(0xFF06B6D4);
  static const Color services = Color(0xFF84CC16);
  static const Color pets = Color(0xFFA855F7);
  static const Color contacts = Color(0xFFE11D48);

  // UI Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color shimmer = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF9FAFB);

  // Featured Ad Colors
  static const Color featuredGold = Color(0xFFFFD700);
  static const Color featuredGradientStart = Color(0xFFFFB347);
  static const Color featuredGradientEnd = Color(0xFFFF6B35);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient foxGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C), Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF2D3047), Color(0xFF4A4E69)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
