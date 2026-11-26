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
  String get fieldStrength => 'শক্তি (mg)';

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
}
