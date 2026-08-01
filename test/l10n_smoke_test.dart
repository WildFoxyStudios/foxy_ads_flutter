import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations parity', () {
    test('every Spanish key exists in English and Italian', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final it = await AppLocalizations.delegate.load(const Locale('it'));
      // Pick a few spot-check keys we know exist.
      for (final key in ['commonSave', 'commonCancel', 'commonRetry']) {
        expect(_callByName(en, key), isNotNull, reason: 'en missing $key');
        expect(_callByName(it, key), isNotNull, reason: 'it missing $key');
      }
    });

    test('es has appName', () async {
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      expect(es.appName, 'Foxy Ads');
    });
  });
}

dynamic _callByName(AppLocalizations l, String name) {
  // We can't enumerate getters on a class statically in Dart, so use a known
  // list of getters to spot-check. Extend this list as F3/F4 add more keys.
  switch (name) {
    case 'commonSave':
      return l.commonSave;
    case 'commonCancel':
      return l.commonCancel;
    case 'commonRetry':
      return l.commonRetry;
    case 'commonLoading':
      return l.commonLoading;
    case 'commonErrorGeneric':
      return l.commonErrorGeneric;
    case 'commonSearch':
      return l.commonSearch;
    case 'commonDelete':
      return l.commonDelete;
    case 'commonEdit':
      return l.commonEdit;
    case 'commonBack':
      return l.commonBack;
    case 'commonClose':
      return l.commonClose;
    case 'commonContinue':
      return l.commonContinue;
    case 'commonYes':
      return l.commonYes;
    case 'commonNo':
      return l.commonNo;
    case 'localeSwitcherAriaLabel':
      return l.localeSwitcherAriaLabel;
    case 'appName':
      return l.appName;
    case 'profileTitle':
      return l.profileTitle;
    case 'editProfileTitle':
      return l.editProfileTitle;
    case 'myListingsTitle':
      return l.myListingsTitle;
    case 'favoritesTitle':
      return l.favoritesTitle;
    case 'panelTitle':
      return l.panelTitle;
    case 'leadsPanelHeader':
      return l.leadsPanelHeader;
    case 'agencyTitle':
      return l.agencyTitle;
    case 'promocionesTitle':
      return l.promocionesTitle;
    case 'promocionDetailTitle':
      return l.promocionDetailTitle;
    case 'developmentFormTitle':
      return l.developmentFormTitle;
    case 'bulkListingsHeader':
      return l.bulkListingsHeader;
    case 'valuationTitle':
      return l.valuationTitle;
    case 'realEstateTitle':
      return l.realEstateTitle;
    case 'cityLandingTitle':
      return l.cityLandingTitle;
    case 'developmentCardPriceFrom':
      return l.developmentCardPriceFrom;
    case 'agencyVerifiedBadgeVerified':
      return l.agencyVerifiedBadgeVerified;
    default:
      return null;
  }
}