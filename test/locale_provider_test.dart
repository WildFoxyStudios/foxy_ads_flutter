import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foxy_ads/core/providers/locale_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to Spanish when no preference saved', () {
    final c = ProviderContainer();
    expect(c.read(localeProvider).languageCode, 'es');
    c.dispose();
  });

  test('setLocale persists and updates state', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    await c.read(localeProvider.notifier).setLocale(const Locale('en'));
    expect(c.read(localeProvider).languageCode, 'en');
    // New container reads back the persisted choice. Allow the Notifier's
    // async `_loadFromPrefs` (which fires from inside `build()`) to complete
    // before asserting — pumpEventQueue drains the microtask queue until idle.
    final c2 = ProviderContainer();
    // First read so `build()` runs and `_loadFromPrefs()` is kicked off.
    c2.read(localeProvider);
    await pumpEventQueue();
    expect(c2.read(localeProvider).languageCode, 'en');
    c.dispose();
    c2.dispose();
  });
}