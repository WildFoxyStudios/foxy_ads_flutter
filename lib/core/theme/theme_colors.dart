import 'package:flutter/material.dart';

/// Theme-aware surface color. Use in place of `AppColors.surface` /
/// `Colors.white` for widget surfaces that should repaint correctly in
/// both light and dark modes. Background widgets that NEED a white surface
/// (e.g. image placeholder) should continue to use `AppColors.surface` directly.
Color surfaceFor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;