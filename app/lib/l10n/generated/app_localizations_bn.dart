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

  @override
  String get phoneTitle => 'আপনার মোবাইল নম্বর';

  @override
  String get phoneHint => '01XXXXXXXXX';

  @override
  String get phoneInvalid => 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন';

  @override
  String get sendCode => 'কোড পাঠান';

  @override
  String get otpTitle => 'কোডটি লিখুন';

  @override
  String otpSubtitle(String phone) {
    return '$phone নম্বরে ৬ সংখ্যার একটি কোড পাঠানো হয়েছে';
  }

  @override
  String get verify => 'যাচাই করুন';

  @override
  String demoModeHint(String code) {
    return 'ডেমো মোড: কোড $code';
  }

  @override
  String get authInvalidCode => 'কোডটি ভুল অথবা মেয়াদ শেষ';

  @override
  String get authSmsFailed => 'SMS পাঠানো যায়নি। আবার চেষ্টা করুন।';

  @override
  String get homeTitle => 'আজকের ওষুধ';

  @override
  String get homeEmpty =>
      'এখনো কোনো ওষুধ নেই। শুরু করতে প্রেসক্রিপশন স্ক্যান করুন।';

  @override
  String get nextDose => 'পরের';

  @override
  String get done => 'শেষ';

  @override
  String get scanPrescription => 'প্রেসক্রিপশন স্ক্যান';

  @override
  String get addManually => 'নিজে যোগ করুন';

  @override
  String get myMedicines => 'আমার ওষুধ';

  @override
  String get signOut => 'সাইন আউট';

  @override
  String get scanTitle => 'প্রেসক্রিপশন স্ক্যান';

  @override
  String get takePhoto => 'ছবি তুলুন';

  @override
  String get chooseFromGallery => 'গ্যালারি থেকে বেছে নিন';

  @override
  String get scanTips =>
      'প্রেসক্রিপশনটা আলোতে সমান করে রাখুন, পুরো পাতা যেন ছবিতে আসে।';

  @override
  String get reading => 'প্রেসক্রিপশন পড়া হচ্ছে…';

  @override
  String get confirmTitle => 'মিলিয়ে দেখে নিশ্চিত করুন';

  @override
  String get confirmHelp =>
      'হলুদ চিহ্নিত প্রতিটা ঘর প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন।';

  @override
  String get confirmButton => 'নিশ্চিত করুন';

  @override
  String get addAnother => 'আরেকটা ওষুধ যোগ করুন';

  @override
  String get removeMedicine => 'বাদ দিন';

  @override
  String get fieldName => 'ওষুধের নাম';

  @override
  String get fieldStrength => 'মাত্রা (mg)';

  @override
  String get fieldDose => 'ডোজ (সকাল+দুপুর+রাত)';

  @override
  String get fieldDoseHint => '১+০+১';

  @override
  String get fieldTiming => 'কখন খাবেন';

  @override
  String get fieldDuration => 'কত দিন';

  @override
  String get continueIndefinitely => 'চলবে (শেষ তারিখ নেই)';

  @override
  String get asNeeded => 'শুধু প্রয়োজন হলে (SOS)';

  @override
  String get looksRight => 'ঠিক আছে';

  @override
  String writtenAs(String text) {
    return 'প্রেসক্রিপশনে লেখা: $text';
  }

  @override
  String get problemNameRequired => 'ওষুধের নাম লিখুন';

  @override
  String get problemDoseInvalid => 'ডোজ লিখুন, যেমন ১+০+১';

  @override
  String get problemDurationRequired => 'কত দিন লিখুন, অথবা \"চলবে\" বেছে নিন';

  @override
  String get problemNeedsReview => 'হলুদ চিহ্নিত ঘরগুলো মিলিয়ে দেখুন';

  @override
  String get timingBeforeMeal => 'খাবারের আগে';

  @override
  String get timingAfterMeal => 'খাবারের পরে';

  @override
  String get timingWithMeal => 'খাবারের সাথে';

  @override
  String get timingEmptyStomach => 'খালি পেটে';

  @override
  String get timingBedtime => 'ঘুমানোর আগে';

  @override
  String get timingNotSpecified => 'লেখা নেই';

  @override
  String get saved => 'সংরক্ষণ হয়েছে। রিমাইন্ডার চালু হয়েছে।';

  @override
  String get stopMedicine => 'এই ওষুধ বন্ধ করুন';

  @override
  String stopConfirm(String name) {
    return '$name-এর রিমাইন্ডার বন্ধ করবেন? শুধু ডাক্তার বললে বন্ধ করুন।';
  }

  @override
  String get cancel => 'বাতিল';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get errorNetwork => 'সার্ভারের সাথে সংযোগ নেই। ইন্টারনেট দেখুন।';

  @override
  String get errorGeneric => 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errImageMissing => 'কোনো ছবি পাওয়া যায়নি।';

  @override
  String get errImageTooLarge => 'ছবিটা অনেক বড় (সর্বোচ্চ ১৫ MB)।';

  @override
  String get errImageUnreadable => 'এটা ছবি নয়। JPEG বা PNG ছবি দিন।';

  @override
  String get errImageFormatUnsupported =>
      'শুধু JPEG, PNG বা WebP ছবি দেওয়া যাবে।';

  @override
  String get errImageTooSmall =>
      'ছবিটা খুব ছোট। প্রেসক্রিপশনের কাছ থেকে তুলুন।';

  @override
  String get errNotAPrescription => 'এটা প্রেসক্রিপশন মনে হচ্ছে না।';

  @override
  String get errAiNotConfigured =>
      'এখন প্রেসক্রিপশন পড়া যাচ্ছে না। ওষুধগুলো নিজে যোগ করুন।';

  @override
  String get errAiRateLimited =>
      'এখন অনেক অনুরোধ আসছে। এক মিনিট পরে চেষ্টা করুন।';

  @override
  String get errAiUnavailable =>
      'প্রেসক্রিপশন পড়ার সেবায় সংযোগ হচ্ছে না। আবার চেষ্টা করুন।';

  @override
  String get errAiRefused => 'এই ছবিটা পড়া যায়নি। ওষুধগুলো নিজে যোগ করুন।';

  @override
  String get errAiFailed => 'প্রেসক্রিপশন পড়া যায়নি। আবার চেষ্টা করুন।';

  @override
  String get errPrescriptionTooLong =>
      'প্রেসক্রিপশনটা অনেক বড়। দুই ভাগে দুটো ছবি তুলুন।';

  @override
  String get errDrugNotFound => 'ওষুধটি পাওয়া যায়নি।';

  @override
  String get errInvalidDosePattern => 'ডোজ সঠিক নয়। ১+০+১ এর মতো লিখুন।';

  @override
  String get errInvalidInterval =>
      'কত ঘণ্টা পরপর, সেটা ২৪ ঘণ্টাকে সমান ভাগ করতে হবে।';

  @override
  String get errInvalidDuration => 'দিনের সংখ্যা ১ থেকে ৩৬৫-এর মধ্যে হতে হবে।';

  @override
  String get errInvalidWeekdays => 'সপ্তাহের অন্তত একটা দিন বেছে নিন।';

  @override
  String get errInvalidMealTimes =>
      'খাবারের সময়গুলো দিনের ক্রম অনুযায়ী হতে হবে।';

  @override
  String get errInvalidTimezone => 'অজানা সময় অঞ্চল।';

  @override
  String get errMissingDose => 'ডোজ লিখুন।';

  @override
  String get errConflictingDose => 'ডোজ অথবা কত ঘণ্টা পরপর, যেকোনো একটা দিন।';

  @override
  String get noticeNameUnreadable => 'নাম পড়া যায়নি।';

  @override
  String get noticeNameNotInCatalog =>
      'এই নাম আমাদের ওষুধের তালিকায় নেই। ভালো করে মিলিয়ে দেখুন।';

  @override
  String noticeNameCorrected(String written) {
    return 'প্রেসক্রিপশনে লেখা \"$written\"।';
  }

  @override
  String noticeStrengthNotInCatalog(String written) {
    return '$written শক্তির ওষুধ আমাদের তালিকায় নেই।';
  }

  @override
  String noticeStrengthSuggested(String suggested) {
    return 'প্রেসক্রিপশনে লেখা নেই; তালিকা থেকে $suggested প্রস্তাব করা হয়েছে।';
  }

  @override
  String noticeDoseUnreadable(String written) {
    return '\"$written\" বোঝা যায়নি।';
  }

  @override
  String get noticeDoseMissing => 'ডোজ লেখা নেই।';

  @override
  String get noticeDoseAsNeeded => 'শুধু প্রয়োজন হলে খাবেন।';

  @override
  String get noticeTimingNotSpecified => 'খাবারের আগে না পরে, লেখা নেই।';

  @override
  String get noticeDurationUnclear => 'কত দিন খাবেন, পরিষ্কার নয়।';

  @override
  String noticeDurationOutOfRange(String days) {
    return 'অস্বাভাবিক মেয়াদ ($days দিন)।';
  }

  @override
  String get noticeDurationMissing => 'কত দিন খেতে হবে লেখা নেই।';

  @override
  String get noticeImagePoorQuality =>
      'ছবিটা অস্পষ্ট। সব মিলিয়ে দেখুন অথবা আবার ছবি তুলুন।';

  @override
  String get noticeNoMedicinesFound =>
      'কোনো ওষুধ পাওয়া যায়নি। নিজে যোগ করুন অথবা আবার ছবি তুলুন।';

  @override
  String get noticeReviewHighlightedFields =>
      'হলুদ চিহ্নিত ঘরগুলো প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন।';

  @override
  String get alarmTitle => 'ওষুধ খাওয়ার সময়';

  @override
  String get alarmChannelName => 'ওষুধের রিমাইন্ডার';

  @override
  String alarmSpeech(String names) {
    return 'এখন আপনার $names খাওয়ার সময়।';
  }

  @override
  String get alarmTaken => 'খেয়েছি';

  @override
  String get alarmSnooze => '১০ মিনিট পরে';

  @override
  String get alarmSkip => 'বাদ দিলাম';

  @override
  String get snoozeLimit => '৩ বার পিছিয়েছেন। এখন খেয়ে নিন অথবা বাদ দিন।';

  @override
  String get horizonNoticeTitle => 'রিমাইন্ডার চালু রাখুন';

  @override
  String get horizonNoticeBody =>
      'অ্যাপটি একবার খুলুন, তাহলে পরের সপ্তাহের রিমাইন্ডার সেট হয়ে যাবে।';

  @override
  String get setupTitle => 'রিমাইন্ডার সেটিংস';

  @override
  String get setupIntro =>
      'ফোন লক বা ইন্টারনেট বন্ধ থাকলেও যেন সময়মতো অ্যালার্ম বাজে, সেজন্য এই সেটিংসগুলো চালু করুন।';

  @override
  String get setupNotifications => 'নোটিফিকেশনের অনুমতি দিন';

  @override
  String get setupExactAlarms => 'ঠিক সময়ে অ্যালার্মের অনুমতি দিন';

  @override
  String get setupFullScreen => 'লক স্ক্রিনে অ্যালার্ম দেখান';

  @override
  String get setupBattery => 'ফোন যেন অ্যাপটি বন্ধ করে না দেয়';

  @override
  String get setupBatteryHelp =>
      'তালিকায় এই অ্যাপটি খুঁজে \"No restrictions\" বেছে নিন অথবা \"Auto start\" চালু করুন।';

  @override
  String get setupOpen => 'খুলুন';

  @override
  String remindersScheduled(int count) {
    return 'আগামী ৭ দিনের জন্য $countটি রিমাইন্ডার সেট হয়েছে';
  }

  @override
  String get offlineNotice => 'ইন্টারনেট নেই: সংরক্ষিত ওষুধ দেখানো হচ্ছে';

  @override
  String get caregiverAlertsChannel => 'পরিবারের সতর্কবার্তা';

  @override
  String get familyTitle => 'পরিবার';

  @override
  String get familyIntro =>
      'পরিবারের সদস্যরা দেখতে পারবেন ওষুধ খাওয়া হলো কিনা, আর কোনো ডোজ বাদ গেলে খবর পাবেন।';

  @override
  String get inviteCaregiver => 'পরিবারের সদস্যকে আমন্ত্রণ';

  @override
  String get permissionView => 'আমার ওষুধ দেখতে পারবেন';

  @override
  String get permissionEdit => 'আমার ওষুধ দেখতে ও যোগ করতে পারবেন';

  @override
  String get inviteCodeTitle => 'আমন্ত্রণ কোড';

  @override
  String get inviteCodeHelp =>
      'কোডটি আপনার পরিবারের সদস্যকে দিন। এটা একবারই, ২৪ ঘণ্টার জন্য কাজ করবে।';

  @override
  String shareCode(String code) {
    return 'আমার ওষুধ রিমাইন্ডার আমন্ত্রণ কোড: $code';
  }

  @override
  String get iAmCaregiver => 'আমি কারো দেখাশোনা করি';

  @override
  String get enterInviteCode => 'আমন্ত্রণ কোডটি লিখুন';

  @override
  String get acceptInvite => 'যুক্ত হোন';

  @override
  String get inviteInvalid => 'কোডটি ভুল, ব্যবহৃত অথবা মেয়াদোত্তীর্ণ।';

  @override
  String get inviteOwn => 'নিজের কোড নিজে ব্যবহার করা যাবে না।';

  @override
  String get myCaregivers => 'যাঁরা আমার দেখাশোনা করেন';

  @override
  String get peopleICareFor => 'যাঁদের আমি দেখাশোনা করি';

  @override
  String get noLinks => 'এখনো কেউ নেই।';

  @override
  String get unnamedPerson => 'পরিবারের সদস্য';

  @override
  String get revoke => 'বাদ দিন';

  @override
  String revokeConfirm(String name) {
    return '$name-কে বাদ দেবেন? তিনি আর ওষুধের তথ্য দেখতে পাবেন না।';
  }

  @override
  String get stateTaken => 'খেয়েছেন';

  @override
  String get stateSkipped => 'বাদ দিয়েছেন';

  @override
  String get stateMissed => 'খাওয়া হয়নি';

  @override
  String get stateDue => 'এখন খাওয়ার সময়';

  @override
  String get stateUpcoming => 'আসছে';

  @override
  String get addForPatient => 'তাঁর জন্য প্রেসক্রিপশন যোগ করুন';

  @override
  String get dashboardEmpty => 'আজ কোনো ডোজ নেই।';

  @override
  String get errAuthRequired => 'অনুগ্রহ করে আবার সাইন ইন করুন।';

  @override
  String get errAuthInvalid => 'আপনার সেশনের মেয়াদ শেষ। আবার সাইন ইন করুন।';

  @override
  String get errRateLimited =>
      'অল্প সময়ে অনেকবার স্ক্যান করেছেন। একটু পরে আবার চেষ্টা করুন।';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get privacySummary =>
      'আপনার প্রেসক্রিপশন ও ওষুধের তথ্য শুধু আপনি এবং আপনার আমন্ত্রিত পরিবারের সদস্যরা দেখতে পারেন। প্রেসক্রিপশনের ছবি কখনো সংরক্ষণ করা হয় না।';

  @override
  String get deleteAccount => 'আমার অ্যাকাউন্ট মুছে দিন';

  @override
  String get deleteAccountConfirm =>
      'এতে আপনার অ্যাকাউন্ট, ওষুধ, ইতিহাস ও পরিবারের সংযোগ চিরতরে মুছে যাবে। এটা আর ফেরানো যাবে না।';

  @override
  String get deleteAccountButton => 'চিরতরে মুছে দিন';

  @override
  String get assistantTitle => 'ওষুধ নিয়ে জিজ্ঞেস করুন';

  @override
  String get assistantHint => 'প্রশ্ন লিখুন বা বলুন';

  @override
  String get assistantIntro =>
      'জিজ্ঞেস করতে পারেন, যেমন \"পরের ওষুধ কখন?\" আমি ডোজ বদলাতে পারি না; সেজন্য ডাক্তারকে জিজ্ঞেস করুন।';

  @override
  String get assistantListening => 'শুনছি…';

  @override
  String get assistantVoiceUnavailable =>
      'এই ফোনে কথা বলে প্রশ্ন করা যাচ্ছে না।';

  @override
  String get call999 => '৯৯৯-এ ফোন করুন';

  @override
  String actionStop(String name) {
    return '$name-এর রিমাইন্ডার বন্ধ করবেন?';
  }

  @override
  String actionMealTime(String meal, String time) {
    return '$meal-এর সময় $time করবেন?';
  }

  @override
  String get actionConfirm => 'নিশ্চিত করুন';

  @override
  String get actionDone => 'হয়ে গেছে';

  @override
  String get mealBreakfast => 'নাস্তা';

  @override
  String get mealLunch => 'দুপুরের খাবার';

  @override
  String get mealEvening => 'বিকেলের নাস্তা';

  @override
  String get mealDinner => 'রাতের খাবার';

  @override
  String get mealBedtime => 'ঘুম';

  @override
  String get refillNoticeTitle => 'ওষুধ শেষ হয়ে আসছে';

  @override
  String refillNoticeBody(String name) {
    return '$name প্রায় ৩ দিনের মধ্যে শেষ হবে। সময়মতো কিনে নিন।';
  }

  @override
  String get lowStockTitle => 'শীঘ্রই শেষ হবে';

  @override
  String lowStockBody(String name, String days) {
    return '$name: আর প্রায় $days দিন চলবে';
  }

  @override
  String get duplicateTitle => 'একই ওষুধ দুইবার?';

  @override
  String duplicateBody(String names, String ingredient) {
    return '$names-এ একই উপাদান ($ingredient) আছে। দুটোই খাওয়ার আগে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।';
  }

  @override
  String get mealShiftTitle => 'খাবারের সময় বদলাবেন?';

  @override
  String mealShiftBody(int days, String meal, String to) {
    return '$days দিন ধরে আপনি $meal-এর ওষুধ $to-এর দিকে খাচ্ছেন। $meal-এর সময় $to করবেন?';
  }

  @override
  String get yes => 'হ্যাঁ';

  @override
  String get no => 'না';

  @override
  String get stockTitle => 'হাতে কয়টা ট্যাবলেট আছে';

  @override
  String get stockHelp => 'এখন হাতে কয়টা ট্যাবলেট (বা ডোজ) আছে গুনে লিখুন।';

  @override
  String daysLeft(String days) {
    return 'আর প্রায় $days দিন চলবে';
  }

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get reportTitle => 'গত ৭ দিন';

  @override
  String reportOverall(int taken, int scheduled, int percent) {
    return '$scheduledটি ডোজের মধ্যে $takenটি খাওয়া হয়েছে ($percent%)';
  }

  @override
  String reportMissed(int missed, int skipped) {
    return 'বাদ পড়েছে: $missed · নিজে বাদ দিয়েছেন: $skipped';
  }

  @override
  String get reportShare => 'রিপোর্ট শেয়ার করুন (PDF)';

  @override
  String get ramadanTitle => 'রমজান মোড';

  @override
  String get ramadanIntro =>
      'সকালের ওষুধ সেহরিতে আর সন্ধ্যার ওষুধ ইফতারে সরিয়ে নেয়।';

  @override
  String get ramadanDistrict => 'জেলা';

  @override
  String ramadanTimes(String sehri, String iftar) {
    return 'আজ সেহরির শেষ সময় $sehri, ইফতার $iftar';
  }

  @override
  String get ramadanConflicts =>
      'এই ওষুধগুলোর ডোজ রোজার সময়ে পড়ছে। রমজানে কীভাবে খাবেন, ডাক্তারকে জিজ্ঞেস করুন:';

  @override
  String get ramadanOn => 'রমজানের সময়সূচি চালু করুন';

  @override
  String get ramadanOff => 'রমজানের সময়সূচি বন্ধ করুন';

  @override
  String get channelsHelp =>
      'কোনো ডোজ \"খেয়েছি\" চিহ্নিত না হলে: ৩০ মিনিট পরে SMS আর ৪৫ মিনিট পরে ফোন কল। এর জন্য আপনার কোনো খরচ নেই।';

  @override
  String get channelSms => 'SMS রিমাইন্ডার';

  @override
  String get channelCall => 'ফোন কলে রিমাইন্ডার';

  @override
  String get featurePhoneMode => 'সাধারণ ফোন (স্মার্টফোন নেই)';

  @override
  String get featurePhoneHelp =>
      'প্রতিটি ডোজের সময় তাঁর ফোনে SMS বা কল যাবে; ওষুধগুলো আপনি এখান থেকে দেখাশোনা করবেন।';

  @override
  String get trainingConsentTitle =>
      'প্রেসক্রিপশন পড়া উন্নত করতে সাহায্য করুন';

  @override
  String get trainingConsentBody =>
      'চালু থাকলে, আপনার স্ক্যান করে নিশ্চিত করা প্রেসক্রিপশনের ছবি আমাদের পাঠক উন্নত করতে ব্যবহার হবে। নাম, বয়স, ফোন নম্বর ও ঠিকানা কালো করে ঢেকে দেওয়া হয়, আর ব্যবহারের আগে একজন মানুষ প্রতিটি ছবি দেখে নেন। যেকোনো সময় বন্ধ করতে পারবেন; তখন অব্যবহৃত ছবি মুছে ফেলা হবে।';

  @override
  String get errTrainingDisabled => 'এখন শেয়ার করা যাচ্ছে না।';

  @override
  String get errTrainingNotConsented => 'আগে সেটিংস থেকে শেয়ার করা চালু করুন।';

  @override
  String get errInvalidLabel => 'প্রেসক্রিপশনের তথ্য শেয়ার করা যায়নি।';

  @override
  String get mealTimesTitle => 'খাবারের সময়';

  @override
  String get mealTimesHelp =>
      'রিমাইন্ডারের সময় এগুলো থেকে হিসাব হয়। খাবারের আগের ওষুধ ৩০ মিনিট আগে, পরের ওষুধ ১৫ মিনিট পরে মনে করানো হয়।';

  @override
  String get mealTimesSaveFailed =>
      'সময় সেভ করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String daysCount(int days) {
    return '$days দিন';
  }

  @override
  String get stopShort => 'বন্ধ';

  @override
  String get reportNoDoses => 'গত ৭ দিনে এখনো কোনো ডোজের সময় হয়নি।';

  @override
  String get updateTitle => 'নতুন সংস্করণ এসেছে';

  @override
  String get updateBody =>
      'নিচের বোতামে চাপুন। ডাউনলোড শেষ হলে ফাইলটি খুলে \"Install\" চাপুন। আপনার ওষুধ ও সাইন ইন ঠিক থাকবে।';

  @override
  String get updateButton => 'আপডেট করুন';

  @override
  String get setupOn => 'চালু আছে';

  @override
  String get setupAlreadyOn => 'এটা আগে থেকেই চালু আছে ✓';

  @override
  String get setupTryAgain => 'এখন খোলা যায়নি। একটু পরে আবার চাপুন।';

  @override
  String get setupTestAlarm => 'পরীক্ষামূলক অ্যালার্ম দিন';

  @override
  String get setupTestAlarmHelp =>
      'সব ঠিক আছে কিনা দেখতে একটা পরীক্ষামূলক অ্যালার্ম দিন। এটা কোনো ডোজ হিসেবে লেখা হবে না।';

  @override
  String get setupTestAlarmScheduled =>
      'এক মিনিটের মধ্যে অ্যালার্ম বাজবে। ফোন লক করে অপেক্ষা করুন।';

  @override
  String get testAlarmLabel => 'পরীক্ষা: অ্যালার্ম ঠিকমতো বাজছে';

  @override
  String get alarmsBlockedTitle => 'অ্যালার্ম বাজবে না';

  @override
  String get alarmsBlockedBody =>
      'নোটিফিকেশন বা ঠিক সময়ের অ্যালার্মের অনুমতি বন্ধ আছে। এখানে চেপে চালু করুন।';

  @override
  String get signInWithPhone => 'ফোন নম্বর দিয়ে সাইন ইন';

  @override
  String get startFailed =>
      'এখন শুরু করা যাচ্ছে না। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get signOutAnonymousWarning =>
      'আপনার অ্যাকাউন্টে কোনো ফোন নম্বর যোগ করা নেই। সাইন আউট করলে আপনার ওষুধের তালিকা ও ইতিহাস আর ফেরত পাওয়া যাবে না।';

  @override
  String priceEach(String price) {
    return 'প্রতিটি $price টাকা';
  }

  @override
  String priceEachApprox(String price) {
    return 'প্রতিটি আনুমানিক $price টাকা';
  }

  @override
  String cheaperAvailable(String brand, String percent) {
    return 'একই ওষুধ কম দামে: $brand ($percent% কম)';
  }

  @override
  String get cheaperTitle => 'একই ওষুধ, কম দামে';

  @override
  String cheaperIntro(String generic, String strength) {
    return 'এগুলোতে একই উপাদান ($generic), একই শক্তি ($strength) ও একই ধরনের ওষুধ।';
  }

  @override
  String cheaperRow(String price, String percent) {
    return 'প্রতিটি $price টাকা · $percent% কম';
  }

  @override
  String cheaperMonthly(String amount) {
    return 'মাসে প্রায় $amount টাকা কম';
  }

  @override
  String cheaperCourse(String amount) {
    return 'এই কোর্সে প্রায় $amount টাকা কম';
  }

  @override
  String get cheaperDisclaimer =>
      'ব্র্যান্ড বদলানোর আগে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন। অ্যাপ নিজে থেকে কিছু বদলাবে না।';

  @override
  String get pricesApproximate => 'দামগুলো আনুমানিক; দোকানে কম-বেশি হতে পারে।';

  @override
  String get widgetNext => 'পরের ওষুধ';

  @override
  String get widgetDue => 'এখন খাওয়ার সময়';

  @override
  String get widgetTomorrow => 'আগামীকাল';

  @override
  String get widgetNoMedicines => 'কোনো ওষুধ যোগ করা হয়নি';

  @override
  String get widgetOpenApp => 'পরের ওষুধ দেখতে অ্যাপ খুলুন';

  @override
  String pricePack(String pack, String price) {
    return '$pack: $price টাকা';
  }

  @override
  String pricePackApprox(String pack, String price) {
    return '$pack: আনুমানিক $price টাকা';
  }

  @override
  String cheaperRowPack(String pack, String price, String percent) {
    return '$pack: $price টাকা · $percent% কম';
  }
}
