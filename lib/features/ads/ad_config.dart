/// Master switch for AdMob. Defaults to FALSE so the app cannot crash
/// before the user configures the AdMob app-id `<meta-data>` in
/// AndroidManifest.xml + Info.plist (see docs/ADMOB_SETUP.md). Flip to
/// true only AFTER that config exists.
const bool kAdsEnabled = false;

/// Google's OFFICIAL public TEST ad unit ids (safe to ship; show test ads).
/// Replace with your real AdMob ad unit ids in production.
class AdUnitIds {
  static const String androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  // TODO(user): replace both with your real AdMob banner ad unit ids.
}
