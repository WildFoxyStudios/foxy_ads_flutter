class Country {
  final String code;
  final String name;
  final String flag;
  final String currency;
  final String currencySymbol;
  final bool isEnabled;
  final int sortOrder;

  Country({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.currencySymbol,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String,
      name: json['name'] as String,
      flag: json['flag'] as String,
      currency: json['currency'] as String,
      currencySymbol: json['currency_symbol'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'flag': flag,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'is_enabled': isEnabled,
      'sort_order': sortOrder,
    };
  }

  static List<Country> defaultCountries = [
    Country(
      code: 'ES',
      name: 'España',
      flag: '🇪🇸',
      currency: 'EUR',
      currencySymbol: '€',
    ),
    Country(
      code: 'MX',
      name: 'México',
      flag: '🇲🇽',
      currency: 'MXN',
      currencySymbol: '\$',
    ),
    Country(
      code: 'AR',
      name: 'Argentina',
      flag: '🇦🇷',
      currency: 'ARS',
      currencySymbol: '\$',
    ),
    Country(
      code: 'CO',
      name: 'Colombia',
      flag: '🇨🇴',
      currency: 'COP',
      currencySymbol: '\$',
    ),
    Country(
      code: 'CL',
      name: 'Chile',
      flag: '🇨🇱',
      currency: 'CLP',
      currencySymbol: '\$',
    ),
    Country(
      code: 'PE',
      name: 'Perú',
      flag: '🇵🇪',
      currency: 'PEN',
      currencySymbol: 'S/',
    ),
    Country(
      code: 'VE',
      name: 'Venezuela',
      flag: '🇻🇪',
      currency: 'USD',
      currencySymbol: '\$',
    ),
    Country(
      code: 'EC',
      name: 'Ecuador',
      flag: '🇪🇨',
      currency: 'USD',
      currencySymbol: '\$',
    ),
    Country(
      code: 'GT',
      name: 'Guatemala',
      flag: '🇬🇹',
      currency: 'GTQ',
      currencySymbol: 'Q',
    ),
    Country(
      code: 'CU',
      name: 'Cuba',
      flag: '🇨🇺',
      currency: 'CUP',
      currencySymbol: '\$',
    ),
    Country(
      code: 'BO',
      name: 'Bolivia',
      flag: '🇧🇴',
      currency: 'BOB',
      currencySymbol: 'Bs',
    ),
    Country(
      code: 'DO',
      name: 'Rep. Dominicana',
      flag: '🇩🇴',
      currency: 'DOP',
      currencySymbol: '\$',
    ),
    Country(
      code: 'HN',
      name: 'Honduras',
      flag: '🇭🇳',
      currency: 'HNL',
      currencySymbol: 'L',
    ),
    Country(
      code: 'PY',
      name: 'Paraguay',
      flag: '🇵🇾',
      currency: 'PYG',
      currencySymbol: '₲',
    ),
    Country(
      code: 'SV',
      name: 'El Salvador',
      flag: '🇸🇻',
      currency: 'USD',
      currencySymbol: '\$',
    ),
    Country(
      code: 'NI',
      name: 'Nicaragua',
      flag: '🇳🇮',
      currency: 'NIO',
      currencySymbol: 'C\$',
    ),
    Country(
      code: 'CR',
      name: 'Costa Rica',
      flag: '🇨🇷',
      currency: 'CRC',
      currencySymbol: '₡',
    ),
    Country(
      code: 'PA',
      name: 'Panamá',
      flag: '🇵🇦',
      currency: 'PAB',
      currencySymbol: 'B/',
    ),
    Country(
      code: 'UY',
      name: 'Uruguay',
      flag: '🇺🇾',
      currency: 'UYU',
      currencySymbol: '\$',
    ),
    Country(
      code: 'US',
      name: 'Estados Unidos',
      flag: '🇺🇸',
      currency: 'USD',
      currencySymbol: '\$',
    ),
  ];
}
