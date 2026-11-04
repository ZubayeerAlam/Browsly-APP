/// Form checks that return a message to show, or null when the value is fine.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a name';
    if (text.length > 100) return 'Please use 100 characters or fewer';
    return null;
  }

  static String? email(String? value) {
    if (_emailPattern.hasMatch(value?.trim() ?? '')) return null;
    return 'Please enter a valid email';
  }

  static String? password(String? value) {
    if ((value ?? '').length < 8) return 'Please use at least 8 characters';
    return null;
  }

  static String? phone(String? value) {
    if (normalizeBangladeshPhone(value ?? '') != null) return null;
    return 'Please enter a valid number, such as 01712345678';
  }

  static String? otp(String? value) {
    if (RegExp(r'^[0-9]{6}$').hasMatch(value?.trim() ?? '')) return null;
    return 'Please enter the 6-digit code';
  }

  static String? required(String? value, String label) {
    if ((value?.trim() ?? '').isEmpty) return 'Please enter $label';
    return null;
  }

  static String? postalCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || RegExp(r'^[0-9]{4}$').hasMatch(text)) return null;
    return 'Postal codes have 4 digits';
  }

  /// Converts `01712345678`, `8801712345678` or `+880 1712-345678` to
  /// `+8801712345678`. Returns null when it isn't a Bangladesh mobile number.
  static String? normalizeBangladeshPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[\s-]'), '');
    final match = RegExp(r'^(?:\+?880|0)(1[3-9][0-9]{8})$').firstMatch(digits);
    return match == null ? null : '+880${match.group(1)}';
  }
}
