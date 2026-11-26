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

  @override
  String get phoneTitle => 'Your mobile number';

  @override
  String get phoneHint => '01XXXXXXXXX';

  @override
  String get phoneInvalid => 'Enter a valid Bangladeshi mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSubtitle(String phone) {
    return 'We sent a 6-digit code to $phone';
  }

  @override
  String get verify => 'Verify';

  @override
  String demoModeHint(String code) {
    return 'Demo mode: the code is $code';
  }

  @override
  String get authInvalidCode => 'The code is wrong or has expired';

  @override
  String get authSmsFailed => 'Could not send the SMS. Try again.';

  @override
  String get homeTitle => 'Today\'s medicines';

  @override
  String get homeEmpty => 'No medicines yet. Scan a prescription to start.';

  @override
  String get nextDose => 'Next';

  @override
  String get done => 'Done';

  @override
  String get scanPrescription => 'Scan prescription';

  @override
  String get addManually => 'Add manually';

  @override
  String get myMedicines => 'My medicines';

  @override
  String get signOut => 'Sign out';

  @override
  String get scanTitle => 'Scan prescription';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get scanTips =>
      'Lay the prescription flat in good light and fit the whole page in the photo.';

  @override
  String get reading => 'Reading the prescription…';

  @override
  String get confirmTitle => 'Check and confirm';

  @override
  String get confirmHelp =>
      'Compare every highlighted field with the prescription.';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get addAnother => 'Add another medicine';

  @override
  String get removeMedicine => 'Remove';

  @override
  String get fieldName => 'Medicine name';

  @override
  String get fieldStrength => 'Strength';

  @override
  String get fieldDose => 'Dose (morning+noon+night)';

  @override
  String get fieldDoseHint => '1+0+1';

  @override
  String get fieldTiming => 'When to take';

  @override
  String get fieldDuration => 'For how many days';

  @override
  String get continueIndefinitely => 'Continue (no end date)';

  @override
  String get asNeeded => 'Only when needed (SOS)';

  @override
  String get looksRight => 'Looks right';

  @override
  String writtenAs(String text) {
    return 'On the prescription: $text';
  }

  @override
  String get problemNameRequired => 'Enter the medicine name';

  @override
  String get problemDoseInvalid => 'Enter the dose like 1+0+1';

  @override
  String get problemDurationRequired =>
      'Enter the number of days or choose Continue';

  @override
  String get problemNeedsReview => 'Check the highlighted fields';

  @override
  String get timingBeforeMeal => 'Before food';

  @override
  String get timingAfterMeal => 'After food';

  @override
  String get timingWithMeal => 'With food';

  @override
  String get timingEmptyStomach => 'On an empty stomach';

  @override
  String get timingBedtime => 'At bedtime';

  @override
  String get timingNotSpecified => 'Not specified';

  @override
  String get saved => 'Saved. Reminders are set.';

  @override
  String get stopMedicine => 'Stop this medicine';

  @override
  String stopConfirm(String name) {
    return 'Stop reminders for $name? Only do this if your doctor told you to.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get errorNetwork =>
      'No connection to the server. Check your internet.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get errImageMissing => 'No photo was received.';

  @override
  String get errImageTooLarge => 'The photo is too large (maximum 15 MB).';

  @override
  String get errImageUnreadable =>
      'This file is not a photo. Use a JPEG or PNG image.';

  @override
  String get errImageFormatUnsupported =>
      'Only JPEG, PNG or WebP photos are accepted.';

  @override
  String get errImageTooSmall =>
      'The photo is too small. Take it closer to the prescription.';

  @override
  String get errNotAPrescription => 'This does not look like a prescription.';

  @override
  String get errAiNotConfigured =>
      'Prescription reading is not available right now. Add the medicines manually.';

  @override
  String get errAiRateLimited =>
      'Many requests right now. Try again in a minute.';

  @override
  String get errAiUnavailable => 'Cannot reach the reading service. Try again.';

  @override
  String get errAiRefused =>
      'This photo could not be read. Add the medicines manually.';

  @override
  String get errAiFailed => 'The prescription could not be read. Try again.';

  @override
  String get errPrescriptionTooLong =>
      'The prescription is too long. Take two photos, half each.';

  @override
  String get errDrugNotFound => 'Medicine not found.';

  @override
  String get errInvalidDosePattern =>
      'The dose is not valid. Write it like 1+0+1.';

  @override
  String get errInvalidInterval => 'Every-N-hours dosing must divide 24 hours.';

  @override
  String get errInvalidDuration =>
      'The number of days must be between 1 and 365.';

  @override
  String get errInvalidWeekdays => 'Choose at least one day of the week.';

  @override
  String get errInvalidMealTimes =>
      'Meal times must be in order through the day.';

  @override
  String get errInvalidTimezone => 'Unknown time zone.';

  @override
  String get errMissingDose => 'Enter a dose.';

  @override
  String get errConflictingDose =>
      'Give either a dose pattern or an interval, not both.';

  @override
  String get noticeNameUnreadable => 'The name could not be read.';

  @override
  String get noticeNameNotInCatalog =>
      'This name is not in our medicine list. Check it carefully.';

  @override
  String noticeNameCorrected(String written) {
    return 'Written as \"$written\" on the prescription.';
  }

  @override
  String noticeStrengthNotInCatalog(String written) {
    return 'No $written version is in our medicine list.';
  }

  @override
  String noticeStrengthSuggested(String suggested) {
    return 'Not written on the prescription; $suggested suggested.';
  }

  @override
  String noticeDoseUnreadable(String written) {
    return 'Could not understand \"$written\".';
  }

  @override
  String get noticeDoseMissing => 'No dose is written.';

  @override
  String get noticeDoseAsNeeded => 'Take only when needed.';

  @override
  String get noticeTimingNotSpecified => 'Before or after food is not written.';

  @override
  String get noticeDurationUnclear => 'The duration is unclear.';

  @override
  String noticeDurationOutOfRange(String days) {
    return 'Unusual duration ($days days).';
  }

  @override
  String get noticeDurationMissing => 'How long to take it is not written.';

  @override
  String get noticeImagePoorQuality =>
      'The photo is unclear. Check everything or take a new photo.';

  @override
  String get noticeNoMedicinesFound =>
      'No medicines were found. Add them manually or take a new photo.';

  @override
  String get noticeReviewHighlightedFields =>
      'Compare the highlighted fields with the prescription.';

  @override
  String get alarmTitle => 'Time for your medicine';

  @override
  String get alarmChannelName => 'Medicine reminders';

  @override
  String alarmSpeech(String names) {
    return 'It is time to take $names.';
  }

  @override
  String get alarmTaken => 'Taken';

  @override
  String get alarmSnooze => 'In 10 minutes';

  @override
  String get alarmSkip => 'Skip';

  @override
  String get snoozeLimit => 'You have snoozed 3 times. Take it now or skip.';

  @override
  String get horizonNoticeTitle => 'Keep your reminders running';

  @override
  String get horizonNoticeBody =>
      'Open the app so we can schedule the next week of reminders.';

  @override
  String get setupTitle => 'Reminder settings';

  @override
  String get setupIntro =>
      'These settings make sure alarms ring on time, even when the phone is locked or offline.';

  @override
  String get setupNotifications => 'Allow notifications';

  @override
  String get setupExactAlarms => 'Allow exact alarms';

  @override
  String get setupFullScreen => 'Show alarms on the lock screen';

  @override
  String get setupBattery => 'Stop the phone from closing the app';

  @override
  String get setupBatteryHelp =>
      'Find this app in the list and choose \"No restrictions\" or turn on \"Auto start\".';

  @override
  String get setupOpen => 'Open';

  @override
  String remindersScheduled(int count) {
    return '$count reminders set for the next 7 days';
  }

  @override
  String get offlineNotice => 'Offline: showing saved medicines';

  @override
  String get caregiverAlertsChannel => 'Family alerts';

  @override
  String get familyTitle => 'Family';

  @override
  String get familyIntro =>
      'Family members can see whether medicines were taken and are alerted when a dose is missed.';

  @override
  String get inviteCaregiver => 'Invite a family member';

  @override
  String get permissionView => 'Can see my medicines';

  @override
  String get permissionEdit => 'Can see and add my medicines';

  @override
  String get inviteCodeTitle => 'Invite code';

  @override
  String get inviteCodeHelp =>
      'Give this code to your family member. It works once, for 24 hours.';

  @override
  String shareCode(String code) {
    return 'My Oshudh Reminder invite code: $code';
  }

  @override
  String get iAmCaregiver => 'I look after someone';

  @override
  String get enterInviteCode => 'Enter the invite code';

  @override
  String get acceptInvite => 'Connect';

  @override
  String get inviteInvalid => 'This code is wrong, used or expired.';

  @override
  String get inviteOwn => 'You cannot use your own code.';

  @override
  String get myCaregivers => 'People who look after me';

  @override
  String get peopleICareFor => 'People I look after';

  @override
  String get noLinks => 'No one yet.';

  @override
  String get unnamedPerson => 'Family member';

  @override
  String get revoke => 'Remove';

  @override
  String revokeConfirm(String name) {
    return 'Remove $name? They will no longer see the medicines.';
  }

  @override
  String get stateTaken => 'Taken';

  @override
  String get stateSkipped => 'Skipped';

  @override
  String get stateMissed => 'Missed';

  @override
  String get stateDue => 'Due now';

  @override
  String get stateUpcoming => 'Upcoming';

  @override
  String get addForPatient => 'Add a prescription for them';

  @override
  String get dashboardEmpty => 'No doses today.';

  @override
  String get errAuthRequired => 'Please sign in again.';

  @override
  String get errAuthInvalid =>
      'Your session has expired. Please sign in again.';

  @override
  String get errRateLimited =>
      'Too many scans in a short time. Try again a little later.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacySummary =>
      'Your prescriptions and medicines are visible only to you and the family members you invite. Prescription photos are never stored.';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountConfirm =>
      'This permanently deletes your account, medicines, history and family links. This cannot be undone.';

  @override
  String get deleteAccountButton => 'Delete permanently';

  @override
  String get assistantTitle => 'Ask about your medicines';

  @override
  String get assistantHint => 'Type or speak your question';

  @override
  String get assistantIntro =>
      'Ask things like \"When is my next medicine?\" I cannot change doses; for that, ask your doctor.';

  @override
  String get assistantListening => 'Listening…';

  @override
  String get assistantVoiceUnavailable =>
      'Voice input is not available on this phone.';

  @override
  String get call999 => 'Call 999';

  @override
  String actionStop(String name) {
    return 'Stop reminders for $name?';
  }

  @override
  String actionMealTime(String meal, String time) {
    return 'Change $meal to $time?';
  }

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionDone => 'Done';

  @override
  String get mealBreakfast => 'breakfast';

  @override
  String get mealLunch => 'lunch';

  @override
  String get mealEvening => 'evening snack';

  @override
  String get mealDinner => 'dinner';

  @override
  String get mealBedtime => 'bedtime';
}
