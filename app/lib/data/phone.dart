/// Bangladeshi mobile numbers: 01[3-9]XXXXXXXX, optionally with +880 / 880 / Bangla digits.
library;

const _bn = {
  '০': '0',
  '১': '1',
  '২': '2',
  '৩': '3',
  '৪': '4',
  '৫': '5',
  '৬': '6',
  '৭': '7',
  '৮': '8',
  '৯': '9',
};
final _mobile = RegExp(r'^01[3-9]\d{8}$');

/// Returns the E.164 form (+8801XXXXXXXXX), or null if [input] is not a valid BD mobile number.
String? normalizeBdPhone(String input) {
  var digits = input
      .split('')
      .map((c) => _bn[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+880')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('880')) {
    digits = '0${digits.substring(3)}';
  }
  return _mobile.hasMatch(digits) ? '+88$digits' : null;
}
