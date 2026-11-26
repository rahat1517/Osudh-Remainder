import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/phone.dart';

void main() {
  const valid = {
    '01712345678': '+8801712345678',
    '+8801812345678': '+8801812345678',
    '8801912345678': '+8801912345678',
    '017-1234-5678': '+8801712345678',
    '০১৭১২৩৪৫৬৭৮': '+8801712345678',
  };
  valid.forEach((input, expected) {
    test('accepts $input', () => expect(normalizeBdPhone(input), expected));
  });
  for (final input in [
    '',
    '1234',
    '01212345678',
    '0171234567',
    '017123456789',
    'abc',
  ]) {
    test('rejects "$input"', () => expect(normalizeBdPhone(input), isNull));
  }
}
