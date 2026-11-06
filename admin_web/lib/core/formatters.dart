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

String formatDate(DateTime date) => DateFormat('d MMM y', 'en_US').format(date);

String formatDateTime(DateTime date) {
  return DateFormat('d MMM y, h:mm a', 'en_US').format(date);
}
