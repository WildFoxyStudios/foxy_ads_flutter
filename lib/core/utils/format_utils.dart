/// Shared formatting helpers for listing cards.
library;

import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

const Map<String, String> _currencySymbols = <String, String>{
  'EUR': '€',
  'USD': r'$',
  'GBP': '£',
  'MXN': r'MXN$',
  'COP': r'COP$',
  'ARS': r'ARS$',
  'CLP': r'CLP$',
  'PEN': 'S/',
  'BRL': r'R$',
  'CHF': 'CHF',
  'JPY': '¥',
  'CNY': '元',
};

/// Formats a listing price using the requested locale and currency.
String formatPrice(num amount, String currencyCode, String locale) {
  final whole = amount == amount.truncateToDouble();
  final code = currencyCode.toUpperCase();
  final symbol = _currencySymbols[code] ?? code;
  return NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: whole ? 0 : 2,
  ).format(amount);
}

/// Formats a date as "<localized month> <year>" (e.g. "Ene 2026") for
/// member-since displays. Mirrors the private `_formatDate` helper in
/// `listing_detail_screen.dart` — the app avoids `DateFormat` for this
/// because it needs the app's own translated month abbreviations rather
/// than `intl`'s locale data.
String formatMonthYear(DateTime date, AppLocalizations l10n) {
  final months = [
    l10n.listingDetailMonthJan,
    l10n.listingDetailMonthFeb,
    l10n.listingDetailMonthMar,
    l10n.listingDetailMonthApr,
    l10n.listingDetailMonthMay,
    l10n.listingDetailMonthJun,
    l10n.listingDetailMonthJul,
    l10n.listingDetailMonthAug,
    l10n.listingDetailMonthSep,
    l10n.listingDetailMonthOct,
    l10n.listingDetailMonthNov,
    l10n.listingDetailMonthDec,
  ];
  return '${months[date.month - 1]} ${date.year}';
}

/// Formats a listing date as a localized relative-day card label.
String formatCardDate(
  DateTime date,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final calendarDate = DateTime(date.year, date.month, date.day);
  final calendarNow = DateTime(reference.year, reference.month, reference.day);
  final days = calendarNow.difference(calendarDate).inDays;
  if (days <= 0) return l10n.listingCardToday;
  if (days == 1) return l10n.listingCardYesterday;
  if (days <= 29) return l10n.listingCardDaysAgo(days);
  if (days <= 364) return l10n.listingCardMonthsAgo(days ~/ 30);
  return l10n.listingCardOverAYear;
}
