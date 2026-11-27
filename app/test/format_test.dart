import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/l10n/format.dart';

void main() {
  test('dose amounts read like prescriptions', () {
    expect(formatAmount('0.5'), '½');
    expect(formatAmount('1'), '1');
    expect(formatAmount('1.5'), '1½');
    expect(formatAmount('0.25'), '¼');
    expect(formatAmount('2 tsf'), '2 tsf'); // not a number: unchanged
    expect(formatPattern('0.5+0+0.5'), '½+0+½');
  });

  test('days left without a pointless decimal', () {
    expect(formatDays(2), '2');
    expect(formatDays(2.5), '2.5');
    expect(formatDays(12.4), '12');
  });
}
