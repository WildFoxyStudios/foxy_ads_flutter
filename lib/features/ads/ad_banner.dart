import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// A banner ad slot. Mirrors where the web shows AdSense (home screen below
/// the featured rail, listing detail near the bottom).
///
/// Entirely gated behind [kAdsEnabled]: while it's false (the shipped
/// default), this renders nothing and never touches the Google Mobile Ads
/// SDK, so the app cannot crash from a missing AdMob app-id in the platform
/// manifests. See docs/ADMOB_SETUP.md for how to turn ads on.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  bool get _supportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (kAdsEnabled && _supportedPlatform) {
      _loadAd();
    }
  }

  void _loadAd() {
    final adUnitId = Platform.isIOS
        ? AdUnitIds.iosBanner
        : AdUnitIds.androidBanner;

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kAdsEnabled || !_supportedPlatform) {
      return const SizedBox.shrink();
    }
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
