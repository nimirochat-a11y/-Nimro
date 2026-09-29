/// Maps a 2-letter country code (as stored on the
/// user at registration) to
/// its currency's 3-letter ISO code and display symbol. Used to show coin
/// prices in each user's local currency while the admin dashboard still
/// prices everything in USD - the conversion is display-only.
///
/// Not exhaustive: unmapped or unknown country codes fall back to USD, which
/// is always a safe, correct default.
class CurrencyByCountry {
  CurrencyByCountry._();

  static const Map<String, _CurrencyInfo> _map = {
    // Egypt
    'EG': _CurrencyInfo('EGP', 'ج.م'),
    // Gulf
    'SA': _CurrencyInfo('SAR', 'ر.س'),
    'AE': _CurrencyInfo('AED', 'د.إ'),
    'KW': _CurrencyInfo('KWD', 'د.ك'),
    'QA': _CurrencyInfo('QAR', 'ر.ق'),
    'BH': _CurrencyInfo('BHD', 'د.ب'),
    'OM': _CurrencyInfo('OMR', 'ر.ع'),
    // Levant / North Africa
    'JO': _CurrencyInfo('JOD', 'د.أ'),
    'LB': _CurrencyInfo('LBP', 'ل.ل'),
    'IQ': _CurrencyInfo('IQD', 'د.ع'),
    'MA': _CurrencyInfo('MAD', 'د.م'),
    'DZ': _CurrencyInfo('DZD', 'د.ج'),
    'TN': _CurrencyInfo('TND', 'د.ت'),
    'LY': _CurrencyInfo('LYD', 'د.ل'),
    'SD': _CurrencyInfo('SDG', 'ج.س'),
    'YE': _CurrencyInfo('YER', 'ر.ي'),
    'PS': _CurrencyInfo('ILS', '₪'),
    // Eurozone (shared currency).
    'DE': _CurrencyInfo('EUR', '€'), 'FR': _CurrencyInfo('EUR', '€'),
    'IT': _CurrencyInfo('EUR', '€'), 'ES': _CurrencyInfo('EUR', '€'),
    'NL': _CurrencyInfo('EUR', '€'), 'BE': _CurrencyInfo('EUR', '€'),
    'PT': _CurrencyInfo('EUR', '€'), 'IE': _CurrencyInfo('EUR', '€'),
    'AT': _CurrencyInfo('EUR', '€'), 'GR': _CurrencyInfo('EUR', '€'),
    'FI': _CurrencyInfo('EUR', '€'),
    // Other major markets.
    'GB': _CurrencyInfo('GBP', '£'),
    'US': _CurrencyInfo('USD', '\$'),
    'CA': _CurrencyInfo('CAD', '\$'),
    'IN': _CurrencyInfo('INR', '₹'),
    'PK': _CurrencyInfo('PKR', '₨'),
    'TR': _CurrencyInfo('TRY', '₺'),
  };

  /// Returns the ISO currency code for [countryCode], or 'USD' when unknown.
  static String codeFor(String? countryCode) {
    if (countryCode == null) return 'USD';
    return _map[countryCode.toUpperCase()]?.code ?? 'USD';
  }

  /// Returns the display symbol for [countryCode], or the ISO code itself
  /// when there is no short symbol (also the USD fallback case).
  static String symbolFor(String? countryCode) {
    if (countryCode == null) return 'USD';
    return _map[countryCode.toUpperCase()]?.symbol ?? 'USD';
  }
}

class _CurrencyInfo {
  final String code;
  final String symbol;
  const _CurrencyInfo(this.code, this.symbol);
}
