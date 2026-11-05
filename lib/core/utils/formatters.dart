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

/// Shows a date such as `5 Nov 2026`.
String formatDate(DateTime date) {
  return DateFormat('d MMM y', 'en_US').format(date);
}

/// Shows a date and time such as `5 Nov, 2:30 PM`.
String formatDateTime(DateTime date) {
  return DateFormat('d MMM, h:mm a', 'en_US').format(date);
}

/// Shortens large counts for statistics, such as `12.5K`.
String formatCompactCount(num count) {
  return NumberFormat.compact(locale: 'en_US').format(count);
}
