import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to the system theme mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('set dark updates state and persists the preference', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).set(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'dark');
  });

  test('loads dark theme mode from preferences', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeProvider);
    await pumpEventQueue();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('user choice wins when set beats load (race guard)', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Subscribe (triggers build + unawaited load), then immediately set dark
    // synchronously — this is the user touching the picker before load resolves.
    container.read(themeModeProvider);
    await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    // Let any in-flight _loadFromPrefs microtask settle.
    await pumpEventQueue();

    // The user's fresh selection must NOT be clobbered by the stale load.
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
