import 'package:intl/intl.dart';

/// Shows money in Taka, such as `৳1,250` or `৳1,250.50`.
String formatTaka(num amount) {
  final hasPaisa = amount != amount.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: '৳',
    decimalDigits: hasPaisa ? 2 : 0,
  ).format(amount);
}

/// Shortens large counts for statistics, such as `12.5K`.
String formatCompactCount(num count) {
  return NumberFormat.compact(locale: 'en_US').format(count);
}
