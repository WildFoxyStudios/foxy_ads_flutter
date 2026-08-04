import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';

  @override
  ThemeMode build() {
    // Capture the synchronous default; load will only override if the user
    // hasn't changed it yet.
    final initial = ThemeMode.system;
    state = initial;
    _loadFromPrefs(initial);
    return initial;
  }

  Future<void> _loadFromPrefs(ThemeMode expected) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null) return;
    final parsed = ThemeMode.values.firstWhere(
      (m) => m.name == v, orElse: () => ThemeMode.system);
    // Only apply if the user hasn't touched the picker since startup.
    if (state == expected && parsed != state) state = parsed;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
