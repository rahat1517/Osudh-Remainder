/// Sehri and iftar times from the sun's position (no network needed).
///
/// Fajr (end of sehri) is when the sun is 18° below the horizon before sunrise (University of Karachi
/// method, used by the Islamic Foundation Bangladesh); iftar is sunset. Algorithm: the standard
/// low-precision solar position model (accurate to about a minute), checked against reference values
/// from the Python `astral` library in test/prayer_times_test.dart (spec/ramadan/vectors.json).
library;

import 'dart:math' as math;

class District {
  const District(this.key, this.latitude, this.longitude);

  final String key;
  final double latitude;
  final double longitude;
}

const districts = [
  District('dhaka', 23.8103, 90.4125),
  District('chattogram', 22.3569, 91.7832),
  District('sylhet', 24.8949, 91.8687),
  District('rajshahi', 24.3745, 88.6042),
  District('khulna', 22.8456, 89.5403),
  District('barishal', 22.7010, 90.3535),
  District('rangpur', 25.7439, 89.2752),
  District('mymensingh', 24.7471, 90.4203),
];

District districtByKey(String key) =>
    districts.firstWhere((d) => d.key == key, orElse: () => districts.first);

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _fix(double a, double b) => a - b * (a / b).floorToDouble();

class _Sun {
  const _Sun(this.declination, this.equationOfTime);

  final double declination; // degrees
  final double equationOfTime; // hours
}

_Sun _sunPosition(double julianDay) {
  final d = julianDay - 2451545.0;
  final g = _fix(357.529 + 0.98560028 * d, 360);
  final q = _fix(280.459 + 0.98564736 * d, 360);
  final l = _fix(
    q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)),
    360,
  );
  final e = 23.439 - 0.00000036 * d;
  final ra = _fix(
    _deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) /
        15,
    24,
  );
  final eqt = q / 15 - ra;
  final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
  return _Sun(decl, eqt - 24 * (eqt / 24).roundToDouble());
}

double _julian(int year, int month, int day) {
  var y = year, m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5;
}

/// Local time (hours) when the sun is [angle]° below the horizon, before (morning) or after noon.
double _timeAtAngle(
  double jd,
  District place,
  double angle, {
  required bool morning,
  required double utcOffset,
}) {
  var t = morning ? 5.0 / 24 : 18.0 / 24; // first guess, refined twice
  late double result;
  for (var i = 0; i < 3; i++) {
    final sun = _sunPosition(jd - place.longitude / 360 + t);
    final noon = 12 - sun.equationOfTime;
    final lat = _rad(place.latitude), decl = _rad(sun.declination);
    final cosH =
        (-math.sin(_rad(angle)) - math.sin(decl) * math.sin(lat)) /
        (math.cos(decl) * math.cos(lat));
    final h = _deg(math.acos(cosH.clamp(-1.0, 1.0))) / 15;
    final solarTime = morning ? noon - h : noon + h;
    t = solarTime / 24;
    result = solarTime + utcOffset - place.longitude / 15;
  }
  return result;
}

/// Minutes since midnight (local, UTC+[utcOffsetHours]) of Fajr and sunset on [date].
({int fajr, int sunset}) sehriIftar(
  DateTime date,
  District place, {
  double utcOffsetHours = 6,
}) {
  final jd = _julian(date.year, date.month, date.day);
  final fajr = _timeAtAngle(
    jd,
    place,
    18,
    morning: true,
    utcOffset: utcOffsetHours,
  );
  final sunset = _timeAtAngle(
    jd,
    place,
    0.833,
    morning: false,
    utcOffset: utcOffsetHours,
  );
  return (fajr: (fajr * 60).floor(), sunset: (sunset * 60).ceil());
}
