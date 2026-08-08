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
