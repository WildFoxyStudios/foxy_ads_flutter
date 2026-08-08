import 'package:flutter/material.dart';

import 'ad_config.dart';

/// A banner ad slot. Mirrors where the web shows AdSense (home screen below
/// the featured rail, listing detail near the bottom).
///
/// The shipped [kAdsEnabled] default is `false`, so this widget renders
/// `SizedBox.shrink()` and never touches any ad SDK. When the user is ready
/// to ship ads:
///   1. Re-add `google_mobile_ads` to pubspec.yaml.
///   2. Add the AdMob `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID">`
///      to AndroidManifest.xml (and the equivalent to Info.plist).
///   3. Replace [AdUnitIds.androidBanner]/[AdUnitIds.iosBanner] with real IDs.
///   4. Flip [kAdsEnabled] to `true` and re-introduce the platform-specific
///      `BannerAd(...)` wiring that used to live here.
///
/// We deliberately do NOT depend on `google_mobile_ads` while it's disabled:
/// the package's `MobileAdsInitProvider` is a native Android ContentProvider
/// that runs at process start (before any Dart code) and hard-crashes the
/// app if the manifest meta-data is missing. The Dart-level `kAdsEnabled`
/// gate cannot prevent that crash.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
