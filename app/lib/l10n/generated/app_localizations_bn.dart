// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'ওষুধ রিমাইন্ডার';

  @override
  String get welcomeTitle => 'স্বাগতম!';

  @override
  String get welcomeSubtitle =>
      'প্রেসক্রিপশনের ছবি তুলুন, বাকিটা আমরা মনে রাখব।';

  @override
  String get getStarted => 'শুরু করুন';

  @override
  String get comingSoon => 'শীঘ্রই আসছে';

  @override
  String get disclaimer => 'এই অ্যাপ ডাক্তারের পরামর্শের বিকল্প নয়।';
}
