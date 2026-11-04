import 'package:browsly_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatTaka shows whole amounts without decimals', () {
    expect(formatTaka(1250), '৳1,250');
    expect(formatTaka(85000), '৳85,000');
  });

  test('formatTaka keeps paisa when present', () {
    expect(formatTaka(1250.5), '৳1,250.50');
  });

  test('formatCompactCount shortens large counts', () {
    expect(formatCompactCount(950), '950');
    expect(formatCompactCount(12500), '12.5K');
    expect(formatCompactCount(48700), '48.7K');
  });
}
