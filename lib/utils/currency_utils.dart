import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(double amount, String currency) {
    switch (currency) {
      case "USD":
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$',
        ).format(amount);

      case "EUR":
        return NumberFormat.currency(
          locale: 'en_EU',
          symbol: '€',
        ).format(amount);

      case "GBP":
        return NumberFormat.currency(
          locale: 'en_GB',
          symbol: '£',
        ).format(amount);

      case "AUD":
        return NumberFormat.currency(
          locale: 'en_AU',
          symbol: '\$',
        ).format(amount);

      case "IDR":
        return NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(amount);

      default:
        return amount.toStringAsFixed(2);
    }
  }
}