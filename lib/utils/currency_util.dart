import 'package:intl/intl.dart';

class CurrencyUtil {
  /// Formats the [amount] with the appropriate prefix for the [countryCode].
  /// Optionally uses [decimals] to format floating point amounts.
  static String format(double amount, String countryCode, {int decimals = 0}) {
    String prefix = '\$'; // Default
    switch (countryCode) {
      case 'MY':
        prefix = 'RM';
        break;
      case 'ID':
        prefix = 'Rp';
        break;
      case 'SG':
        prefix = 'S\$';
        break;
      case 'TH':
        prefix = '฿';
        break;
      case 'PH':
        prefix = '₱';
        break;
      case 'VN':
        prefix = '₫';
        break;
    }
    
    // Add comma formatting for large numbers
    final numberFormat = NumberFormat.currency(
      locale: 'en_US', 
      symbol: prefix,
      decimalDigits: decimals,
    );
    
    return numberFormat.format(amount);
  }
}
