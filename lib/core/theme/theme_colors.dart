import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension on BuildContext for quick, clean, theme-aware colors
extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get surfaceColor => colorScheme.surface;
  Color get surfaceContainerColor =>
      isDarkMode ? const Color(0xFF1E293B) : AppColors.surface;
  Color get scaffoldBgColor => Theme.of(this).scaffoldBackgroundColor;
  Color get textPrimaryColor => colorScheme.onSurface;
  Color get textSecondaryColor =>
      isDarkMode ? const Color(0xFF94A3B8) : AppColors.textSecondary;
  Color get borderColor =>
      isDarkMode ? const Color(0xFF334155) : AppColors.border;
  Color get dividerColor =>
      isDarkMode ? const Color(0xFF334155) : AppColors.divider;
  Color get shimmerColor =>
      isDarkMode ? const Color(0xFF1E293B) : AppColors.shimmer;
}

/// Theme-aware surface color.
Color surfaceFor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

/// Theme-aware surface container color for message bubbles, inputs, and chips.
Color surfaceContainerFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF263345)
        : const Color(0xFFF1F5F9);

/// Theme-aware primary text color.
Color textPrimaryFor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Theme-aware secondary text color.
Color textSecondaryFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

/// Theme-aware border color.
Color borderFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : AppColors.border;

/// Theme-aware shimmer / placeholder background color.
Color shimmerFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : AppColors.shimmer;