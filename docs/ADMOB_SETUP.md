# AdMob setup (banner ads)

The app ships with `google_mobile_ads` wired up but **ads are OFF by
default** (`kAdsEnabled = false` in `lib/features/ads/ad_config.dart`).
`AdBanner` renders `SizedBox.shrink()` and `MobileAds.instance.initialize()`
is never called while that flag is false.

**Do not flip the flag to `true` until you've done steps 1-4 below.**
Initializing the Google Mobile Ads SDK, or loading any ad, without the AdMob
app-id `<meta-data>` present in the platform manifests **crashes the app on
launch**. Those manifests (`android/app/src/main/AndroidManifest.xml`,
`ios/Runner/Info.plist`) are yours to edit — this change intentionally
didn't touch them.

## Step 1 — Create an AdMob account + register the app

Go to https://admob.google.com, create an account if needed, and register
the Android and/or iOS app. You'll get an **AdMob App ID** per platform,
formatted `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.

## Step 2 — Android: add the app-id meta-data

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`, add:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

For local testing before you have a real App ID, Google's official test
App ID is safe to use: `ca-app-pub-3940256099942544~3347511713`.

## Step 3 — iOS: add the app-id to Info.plist

In `ios/Runner/Info.plist`, add:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

(same test App ID works here too while developing.)

## Step 4 — Replace the test ad unit ids

`lib/features/ads/ad_config.dart` ships Google's official public **test**
banner ad unit ids (safe to leave in during development — they always
serve test creatives, never real ones):

```dart
class AdUnitIds {
  static const String androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBanner = 'ca-app-pub-3940256099942544/2934735716';
}
```

Once you've created real banner ad units in the AdMob console, replace both
values with your real ad unit ids.

## Step 5 — Flip the flag

Only after steps 2-4 are done, set in `lib/features/ads/ad_config.dart`:

```dart
const bool kAdsEnabled = true;
```

This is the single switch that turns on `MobileAds.instance.initialize()`
in `lib/main.dart` and makes `AdBanner` (mounted on the home screen and the
listing detail screen) actually load and render ads.

## Warning

**Flipping `kAdsEnabled = true` before adding the manifest meta-data (step
2) will crash the app on launch.** Always do steps 2-4 first, verify the
manifest/plist changes are in place, and only then do step 5.
