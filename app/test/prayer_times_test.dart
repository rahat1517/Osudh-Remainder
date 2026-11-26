import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/insights/prayer_times.dart';

int _minutes(String hms) {
  final p = hms.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1] + (p[2] >= 30 ? 1 : 0);
}

void main() {
  final vectors = jsonDecode(
    File('../spec/ramadan/vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final c in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
    test(
      '${c['district']} ${c['date']} matches the astral reference within 2 minutes',
      () {
        final t = sehriIftar(
          DateTime.parse(c['date'] as String),
          districtByKey(c['district'] as String),
        );
        expect(
          (t.fajr - _minutes(c['fajr'] as String)).abs(),
          lessThanOrEqualTo(2),
          reason: 'fajr',
        );
        expect(
          (t.sunset - _minutes(c['sunset'] as String)).abs(),
          lessThanOrEqualTo(2),
          reason: 'sunset',
        );
      },
    );
  }

  test('rounding is conservative: sehri ends no later, iftar no earlier than computed', () {
    // floor for Fajr, ceil for sunset
    final t = sehriIftar(DateTime(2027, 2, 23), districtByKey('dhaka'));
    expect(t.fajr, lessThanOrEqualTo(5 * 60 + 11));
    expect(t.sunset, greaterThanOrEqualTo(17 * 60 + 57));
  });
}
