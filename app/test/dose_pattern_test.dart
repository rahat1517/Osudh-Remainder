import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/schedule/dose_pattern.dart';

void main() {
  // Same cases as backend/tests/test_dose.py, so both parsers agree.
  const valid = {
    '1+0+1': '1+0+1',
    '১+০+১': '1+0+1',
    '1 - 0 - 1': '1+0+1',
    '½+0+½': '0.5+0+0.5',
    '0+0+1/2': '0+0+0.5',
    '1+1+1+1': '1+1+1+1',
    '2+0+2': '2+0+2',
    '1+1': '1+1',
  };
  const invalid = [
    null,
    '',
    'BD',
    '1',
    '0+0+0',
    '1+0+1+1+1',
    '10+0+10',
    'a+b+c',
    '1/0+0+1',
  ];

  valid.forEach((input, expected) {
    test(
      'normalises "$input"',
      () => expect(normalizeDosePattern(input), expected),
    );
  });
  for (final input in invalid) {
    test('rejects "$input"', () => expect(normalizeDosePattern(input), isNull));
  }

  test('formatAmount matches Python %g', () {
    expect(formatAmount(1), '1');
    expect(formatAmount(0.5), '0.5');
    expect(formatAmount(0.25), '0.25');
    expect(formatAmount(1 / 3), '0.333333');
  });
}
