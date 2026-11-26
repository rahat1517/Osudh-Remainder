// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Oshudh Reminder';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeSubtitle =>
      'Take a photo of your prescription, we will remember the rest.';

  @override
  String get getStarted => 'Get started';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get disclaimer => 'This app does not replace your doctor\'s advice.';
}
