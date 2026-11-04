import 'package:browsly_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBangladeshPhone', () {
    test('accepts common formats', () {
      for (final input in [
        '01712345678',
        '8801712345678',
        '+8801712345678',
        '+880 1712-345678',
        '017 1234 5678',
      ]) {
        expect(
          Validators.normalizeBangladeshPhone(input),
          '+8801712345678',
          reason: input,
        );
      }
    });

    test('rejects numbers that are not Bangladesh mobiles', () {
      for (final input in [
        '',
        '0171234567',
        '017123456789',
        '01212345678',
        '+14155550100',
        'abcdefghijk',
      ]) {
        expect(
          Validators.normalizeBangladeshPhone(input),
          isNull,
          reason: input,
        );
      }
    });
  });

  test('email', () {
    expect(Validators.email(' a@example.com '), isNull);
    expect(Validators.email('a@example'), isNotNull);
    expect(Validators.email('a b@example.com'), isNotNull);
    expect(Validators.email(null), isNotNull);
  });

  test('password needs 8 characters', () {
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.password('12345678'), isNull);
  });

  test('otp needs 6 digits', () {
    expect(Validators.otp('123456'), isNull);
    expect(Validators.otp('12345'), isNotNull);
    expect(Validators.otp('12345a'), isNotNull);
  });

  test('postal code is optional but must have 4 digits', () {
    expect(Validators.postalCode(''), isNull);
    expect(Validators.postalCode('1205'), isNull);
    expect(Validators.postalCode('123'), isNotNull);
  });

  test('name', () {
    expect(Validators.name('  '), isNotNull);
    expect(Validators.name('Rafi'), isNull);
    expect(Validators.name('x' * 101), isNotNull);
  });
}
