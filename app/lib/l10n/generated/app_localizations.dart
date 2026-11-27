import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// App name shown in the title bar and launcher
  ///
  /// In bn, this message translates to:
  /// **'ওষুধ রিমাইন্ডার'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In bn, this message translates to:
  /// **'স্বাগতম!'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনের ছবি তুলুন, বাকিটা আমরা মনে রাখব।'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In bn, this message translates to:
  /// **'শুরু করুন'**
  String get getStarted;

  /// No description provided for @comingSoon.
  ///
  /// In bn, this message translates to:
  /// **'শীঘ্রই আসছে'**
  String get comingSoon;

  /// No description provided for @disclaimer.
  ///
  /// In bn, this message translates to:
  /// **'এই অ্যাপ ডাক্তারের পরামর্শের বিকল্প নয়।'**
  String get disclaimer;

  /// No description provided for @phoneTitle.
  ///
  /// In bn, this message translates to:
  /// **'আপনার মোবাইল নম্বর'**
  String get phoneTitle;

  /// No description provided for @phoneHint.
  ///
  /// In bn, this message translates to:
  /// **'01XXXXXXXXX'**
  String get phoneHint;

  /// No description provided for @phoneInvalid.
  ///
  /// In bn, this message translates to:
  /// **'সঠিক বাংলাদেশি মোবাইল নম্বর দিন'**
  String get phoneInvalid;

  /// No description provided for @sendCode.
  ///
  /// In bn, this message translates to:
  /// **'কোড পাঠান'**
  String get sendCode;

  /// No description provided for @otpTitle.
  ///
  /// In bn, this message translates to:
  /// **'কোডটি লিখুন'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'{phone} নম্বরে ৬ সংখ্যার একটি কোড পাঠানো হয়েছে'**
  String otpSubtitle(String phone);

  /// No description provided for @verify.
  ///
  /// In bn, this message translates to:
  /// **'যাচাই করুন'**
  String get verify;

  /// No description provided for @demoModeHint.
  ///
  /// In bn, this message translates to:
  /// **'ডেমো মোড: কোড {code}'**
  String demoModeHint(String code);

  /// No description provided for @authInvalidCode.
  ///
  /// In bn, this message translates to:
  /// **'কোডটি ভুল অথবা মেয়াদ শেষ'**
  String get authInvalidCode;

  /// No description provided for @authSmsFailed.
  ///
  /// In bn, this message translates to:
  /// **'SMS পাঠানো যায়নি। আবার চেষ্টা করুন।'**
  String get authSmsFailed;

  /// No description provided for @homeTitle.
  ///
  /// In bn, this message translates to:
  /// **'আজকের ওষুধ'**
  String get homeTitle;

  /// No description provided for @homeEmpty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো ওষুধ নেই। শুরু করতে প্রেসক্রিপশন স্ক্যান করুন।'**
  String get homeEmpty;

  /// No description provided for @nextDose.
  ///
  /// In bn, this message translates to:
  /// **'পরের'**
  String get nextDose;

  /// No description provided for @done.
  ///
  /// In bn, this message translates to:
  /// **'শেষ'**
  String get done;

  /// No description provided for @scanPrescription.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন স্ক্যান'**
  String get scanPrescription;

  /// No description provided for @addManually.
  ///
  /// In bn, this message translates to:
  /// **'নিজে যোগ করুন'**
  String get addManually;

  /// No description provided for @myMedicines.
  ///
  /// In bn, this message translates to:
  /// **'আমার ওষুধ'**
  String get myMedicines;

  /// No description provided for @signOut.
  ///
  /// In bn, this message translates to:
  /// **'সাইন আউট'**
  String get signOut;

  /// No description provided for @scanTitle.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন স্ক্যান'**
  String get scanTitle;

  /// No description provided for @takePhoto.
  ///
  /// In bn, this message translates to:
  /// **'ছবি তুলুন'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In bn, this message translates to:
  /// **'গ্যালারি থেকে বেছে নিন'**
  String get chooseFromGallery;

  /// No description provided for @scanTips.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনটা আলোতে সমান করে রাখুন, পুরো পাতা যেন ছবিতে আসে।'**
  String get scanTips;

  /// No description provided for @reading.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন পড়া হচ্ছে…'**
  String get reading;

  /// No description provided for @confirmTitle.
  ///
  /// In bn, this message translates to:
  /// **'মিলিয়ে দেখে নিশ্চিত করুন'**
  String get confirmTitle;

  /// No description provided for @confirmHelp.
  ///
  /// In bn, this message translates to:
  /// **'হলুদ চিহ্নিত প্রতিটা ঘর প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন।'**
  String get confirmHelp;

  /// No description provided for @confirmButton.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত করুন'**
  String get confirmButton;

  /// No description provided for @addAnother.
  ///
  /// In bn, this message translates to:
  /// **'আরেকটা ওষুধ যোগ করুন'**
  String get addAnother;

  /// No description provided for @removeMedicine.
  ///
  /// In bn, this message translates to:
  /// **'বাদ দিন'**
  String get removeMedicine;

  /// No description provided for @fieldName.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধের নাম'**
  String get fieldName;

  /// No description provided for @fieldStrength.
  ///
  /// In bn, this message translates to:
  /// **'শক্তি (mg)'**
  String get fieldStrength;

  /// No description provided for @fieldDose.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ (সকাল+দুপুর+রাত)'**
  String get fieldDose;

  /// No description provided for @fieldDoseHint.
  ///
  /// In bn, this message translates to:
  /// **'১+০+১'**
  String get fieldDoseHint;

  /// No description provided for @fieldTiming.
  ///
  /// In bn, this message translates to:
  /// **'কখন খাবেন'**
  String get fieldTiming;

  /// No description provided for @fieldDuration.
  ///
  /// In bn, this message translates to:
  /// **'কত দিন'**
  String get fieldDuration;

  /// No description provided for @continueIndefinitely.
  ///
  /// In bn, this message translates to:
  /// **'চলবে (শেষ তারিখ নেই)'**
  String get continueIndefinitely;

  /// No description provided for @asNeeded.
  ///
  /// In bn, this message translates to:
  /// **'শুধু প্রয়োজন হলে (SOS)'**
  String get asNeeded;

  /// No description provided for @looksRight.
  ///
  /// In bn, this message translates to:
  /// **'ঠিক আছে'**
  String get looksRight;

  /// No description provided for @writtenAs.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনে লেখা: {text}'**
  String writtenAs(String text);

  /// No description provided for @problemNameRequired.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধের নাম লিখুন'**
  String get problemNameRequired;

  /// No description provided for @problemDoseInvalid.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ লিখুন, যেমন ১+০+১'**
  String get problemDoseInvalid;

  /// No description provided for @problemDurationRequired.
  ///
  /// In bn, this message translates to:
  /// **'কত দিন লিখুন, অথবা \"চলবে\" বেছে নিন'**
  String get problemDurationRequired;

  /// No description provided for @problemNeedsReview.
  ///
  /// In bn, this message translates to:
  /// **'হলুদ চিহ্নিত ঘরগুলো মিলিয়ে দেখুন'**
  String get problemNeedsReview;

  /// No description provided for @timingBeforeMeal.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের আগে'**
  String get timingBeforeMeal;

  /// No description provided for @timingAfterMeal.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের পরে'**
  String get timingAfterMeal;

  /// No description provided for @timingWithMeal.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের সাথে'**
  String get timingWithMeal;

  /// No description provided for @timingEmptyStomach.
  ///
  /// In bn, this message translates to:
  /// **'খালি পেটে'**
  String get timingEmptyStomach;

  /// No description provided for @timingBedtime.
  ///
  /// In bn, this message translates to:
  /// **'ঘুমানোর আগে'**
  String get timingBedtime;

  /// No description provided for @timingNotSpecified.
  ///
  /// In bn, this message translates to:
  /// **'লেখা নেই'**
  String get timingNotSpecified;

  /// No description provided for @saved.
  ///
  /// In bn, this message translates to:
  /// **'সংরক্ষণ হয়েছে। রিমাইন্ডার চালু হয়েছে।'**
  String get saved;

  /// No description provided for @stopMedicine.
  ///
  /// In bn, this message translates to:
  /// **'এই ওষুধ বন্ধ করুন'**
  String get stopMedicine;

  /// No description provided for @stopConfirm.
  ///
  /// In bn, this message translates to:
  /// **'{name}-এর রিমাইন্ডার বন্ধ করবেন? শুধু ডাক্তার বললে বন্ধ করুন।'**
  String stopConfirm(String name);

  /// No description provided for @cancel.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get retry;

  /// No description provided for @errorNetwork.
  ///
  /// In bn, this message translates to:
  /// **'সার্ভারের সাথে সংযোগ নেই। ইন্টারনেট দেখুন।'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In bn, this message translates to:
  /// **'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।'**
  String get errorGeneric;

  /// No description provided for @errImageMissing.
  ///
  /// In bn, this message translates to:
  /// **'কোনো ছবি পাওয়া যায়নি।'**
  String get errImageMissing;

  /// No description provided for @errImageTooLarge.
  ///
  /// In bn, this message translates to:
  /// **'ছবিটা অনেক বড় (সর্বোচ্চ ১৫ MB)।'**
  String get errImageTooLarge;

  /// No description provided for @errImageUnreadable.
  ///
  /// In bn, this message translates to:
  /// **'এটা ছবি নয়। JPEG বা PNG ছবি দিন।'**
  String get errImageUnreadable;

  /// No description provided for @errImageFormatUnsupported.
  ///
  /// In bn, this message translates to:
  /// **'শুধু JPEG, PNG বা WebP ছবি দেওয়া যাবে।'**
  String get errImageFormatUnsupported;

  /// No description provided for @errImageTooSmall.
  ///
  /// In bn, this message translates to:
  /// **'ছবিটা খুব ছোট। প্রেসক্রিপশনের কাছ থেকে তুলুন।'**
  String get errImageTooSmall;

  /// No description provided for @errNotAPrescription.
  ///
  /// In bn, this message translates to:
  /// **'এটা প্রেসক্রিপশন মনে হচ্ছে না।'**
  String get errNotAPrescription;

  /// No description provided for @errAiNotConfigured.
  ///
  /// In bn, this message translates to:
  /// **'এখন প্রেসক্রিপশন পড়া যাচ্ছে না। ওষুধগুলো নিজে যোগ করুন।'**
  String get errAiNotConfigured;

  /// No description provided for @errAiRateLimited.
  ///
  /// In bn, this message translates to:
  /// **'এখন অনেক অনুরোধ আসছে। এক মিনিট পরে চেষ্টা করুন।'**
  String get errAiRateLimited;

  /// No description provided for @errAiUnavailable.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন পড়ার সেবায় সংযোগ হচ্ছে না। আবার চেষ্টা করুন।'**
  String get errAiUnavailable;

  /// No description provided for @errAiRefused.
  ///
  /// In bn, this message translates to:
  /// **'এই ছবিটা পড়া যায়নি। ওষুধগুলো নিজে যোগ করুন।'**
  String get errAiRefused;

  /// No description provided for @errAiFailed.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন পড়া যায়নি। আবার চেষ্টা করুন।'**
  String get errAiFailed;

  /// No description provided for @errPrescriptionTooLong.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনটা অনেক বড়। দুই ভাগে দুটো ছবি তুলুন।'**
  String get errPrescriptionTooLong;

  /// No description provided for @errDrugNotFound.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধটি পাওয়া যায়নি।'**
  String get errDrugNotFound;

  /// No description provided for @errInvalidDosePattern.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ সঠিক নয়। ১+০+১ এর মতো লিখুন।'**
  String get errInvalidDosePattern;

  /// No description provided for @errInvalidInterval.
  ///
  /// In bn, this message translates to:
  /// **'কত ঘণ্টা পরপর, সেটা ২৪ ঘণ্টাকে সমান ভাগ করতে হবে।'**
  String get errInvalidInterval;

  /// No description provided for @errInvalidDuration.
  ///
  /// In bn, this message translates to:
  /// **'দিনের সংখ্যা ১ থেকে ৩৬৫-এর মধ্যে হতে হবে।'**
  String get errInvalidDuration;

  /// No description provided for @errInvalidWeekdays.
  ///
  /// In bn, this message translates to:
  /// **'সপ্তাহের অন্তত একটা দিন বেছে নিন।'**
  String get errInvalidWeekdays;

  /// No description provided for @errInvalidMealTimes.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের সময়গুলো দিনের ক্রম অনুযায়ী হতে হবে।'**
  String get errInvalidMealTimes;

  /// No description provided for @errInvalidTimezone.
  ///
  /// In bn, this message translates to:
  /// **'অজানা সময় অঞ্চল।'**
  String get errInvalidTimezone;

  /// No description provided for @errMissingDose.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ লিখুন।'**
  String get errMissingDose;

  /// No description provided for @errConflictingDose.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ অথবা কত ঘণ্টা পরপর, যেকোনো একটা দিন।'**
  String get errConflictingDose;

  /// No description provided for @noticeNameUnreadable.
  ///
  /// In bn, this message translates to:
  /// **'নাম পড়া যায়নি।'**
  String get noticeNameUnreadable;

  /// No description provided for @noticeNameNotInCatalog.
  ///
  /// In bn, this message translates to:
  /// **'এই নাম আমাদের ওষুধের তালিকায় নেই। ভালো করে মিলিয়ে দেখুন।'**
  String get noticeNameNotInCatalog;

  /// No description provided for @noticeNameCorrected.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনে লেখা \"{written}\"।'**
  String noticeNameCorrected(String written);

  /// No description provided for @noticeStrengthNotInCatalog.
  ///
  /// In bn, this message translates to:
  /// **'{written} শক্তির ওষুধ আমাদের তালিকায় নেই।'**
  String noticeStrengthNotInCatalog(String written);

  /// No description provided for @noticeStrengthSuggested.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনে লেখা নেই; তালিকা থেকে {suggested} প্রস্তাব করা হয়েছে।'**
  String noticeStrengthSuggested(String suggested);

  /// No description provided for @noticeDoseUnreadable.
  ///
  /// In bn, this message translates to:
  /// **'\"{written}\" বোঝা যায়নি।'**
  String noticeDoseUnreadable(String written);

  /// No description provided for @noticeDoseMissing.
  ///
  /// In bn, this message translates to:
  /// **'ডোজ লেখা নেই।'**
  String get noticeDoseMissing;

  /// No description provided for @noticeDoseAsNeeded.
  ///
  /// In bn, this message translates to:
  /// **'শুধু প্রয়োজন হলে খাবেন।'**
  String get noticeDoseAsNeeded;

  /// No description provided for @noticeTimingNotSpecified.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের আগে না পরে, লেখা নেই।'**
  String get noticeTimingNotSpecified;

  /// No description provided for @noticeDurationUnclear.
  ///
  /// In bn, this message translates to:
  /// **'কত দিন খাবেন, পরিষ্কার নয়।'**
  String get noticeDurationUnclear;

  /// No description provided for @noticeDurationOutOfRange.
  ///
  /// In bn, this message translates to:
  /// **'অস্বাভাবিক মেয়াদ ({days} দিন)।'**
  String noticeDurationOutOfRange(String days);

  /// No description provided for @noticeDurationMissing.
  ///
  /// In bn, this message translates to:
  /// **'কত দিন খেতে হবে লেখা নেই।'**
  String get noticeDurationMissing;

  /// No description provided for @noticeImagePoorQuality.
  ///
  /// In bn, this message translates to:
  /// **'ছবিটা অস্পষ্ট। সব মিলিয়ে দেখুন অথবা আবার ছবি তুলুন।'**
  String get noticeImagePoorQuality;

  /// No description provided for @noticeNoMedicinesFound.
  ///
  /// In bn, this message translates to:
  /// **'কোনো ওষুধ পাওয়া যায়নি। নিজে যোগ করুন অথবা আবার ছবি তুলুন।'**
  String get noticeNoMedicinesFound;

  /// No description provided for @noticeReviewHighlightedFields.
  ///
  /// In bn, this message translates to:
  /// **'হলুদ চিহ্নিত ঘরগুলো প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন।'**
  String get noticeReviewHighlightedFields;

  /// No description provided for @alarmTitle.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধ খাওয়ার সময়'**
  String get alarmTitle;

  /// No description provided for @alarmChannelName.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধের রিমাইন্ডার'**
  String get alarmChannelName;

  /// No description provided for @alarmSpeech.
  ///
  /// In bn, this message translates to:
  /// **'এখন আপনার {names} খাওয়ার সময়।'**
  String alarmSpeech(String names);

  /// No description provided for @alarmTaken.
  ///
  /// In bn, this message translates to:
  /// **'খেয়েছি'**
  String get alarmTaken;

  /// No description provided for @alarmSnooze.
  ///
  /// In bn, this message translates to:
  /// **'১০ মিনিট পরে'**
  String get alarmSnooze;

  /// No description provided for @alarmSkip.
  ///
  /// In bn, this message translates to:
  /// **'বাদ দিলাম'**
  String get alarmSkip;

  /// No description provided for @snoozeLimit.
  ///
  /// In bn, this message translates to:
  /// **'৩ বার পিছিয়েছেন। এখন খেয়ে নিন অথবা বাদ দিন।'**
  String get snoozeLimit;

  /// No description provided for @horizonNoticeTitle.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডার চালু রাখুন'**
  String get horizonNoticeTitle;

  /// No description provided for @horizonNoticeBody.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপটি একবার খুলুন, তাহলে পরের সপ্তাহের রিমাইন্ডার সেট হয়ে যাবে।'**
  String get horizonNoticeBody;

  /// No description provided for @setupTitle.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডার সেটিংস'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In bn, this message translates to:
  /// **'ফোন লক বা ইন্টারনেট বন্ধ থাকলেও যেন সময়মতো অ্যালার্ম বাজে, সেজন্য এই সেটিংসগুলো চালু করুন।'**
  String get setupIntro;

  /// No description provided for @setupNotifications.
  ///
  /// In bn, this message translates to:
  /// **'নোটিফিকেশনের অনুমতি দিন'**
  String get setupNotifications;

  /// No description provided for @setupExactAlarms.
  ///
  /// In bn, this message translates to:
  /// **'ঠিক সময়ে অ্যালার্মের অনুমতি দিন'**
  String get setupExactAlarms;

  /// No description provided for @setupFullScreen.
  ///
  /// In bn, this message translates to:
  /// **'লক স্ক্রিনে অ্যালার্ম দেখান'**
  String get setupFullScreen;

  /// No description provided for @setupBattery.
  ///
  /// In bn, this message translates to:
  /// **'ফোন যেন অ্যাপটি বন্ধ করে না দেয়'**
  String get setupBattery;

  /// No description provided for @setupBatteryHelp.
  ///
  /// In bn, this message translates to:
  /// **'তালিকায় এই অ্যাপটি খুঁজে \"No restrictions\" বেছে নিন অথবা \"Auto start\" চালু করুন।'**
  String get setupBatteryHelp;

  /// No description provided for @setupOpen.
  ///
  /// In bn, this message translates to:
  /// **'খুলুন'**
  String get setupOpen;

  /// No description provided for @remindersScheduled.
  ///
  /// In bn, this message translates to:
  /// **'আগামী ৭ দিনের জন্য {count}টি রিমাইন্ডার সেট হয়েছে'**
  String remindersScheduled(int count);

  /// No description provided for @offlineNotice.
  ///
  /// In bn, this message translates to:
  /// **'ইন্টারনেট নেই: সংরক্ষিত ওষুধ দেখানো হচ্ছে'**
  String get offlineNotice;

  /// No description provided for @caregiverAlertsChannel.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারের সতর্কবার্তা'**
  String get caregiverAlertsChannel;

  /// No description provided for @familyTitle.
  ///
  /// In bn, this message translates to:
  /// **'পরিবার'**
  String get familyTitle;

  /// No description provided for @familyIntro.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারের সদস্যরা দেখতে পারবেন ওষুধ খাওয়া হলো কিনা, আর কোনো ডোজ বাদ গেলে খবর পাবেন।'**
  String get familyIntro;

  /// No description provided for @inviteCaregiver.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারের সদস্যকে আমন্ত্রণ'**
  String get inviteCaregiver;

  /// No description provided for @permissionView.
  ///
  /// In bn, this message translates to:
  /// **'আমার ওষুধ দেখতে পারবেন'**
  String get permissionView;

  /// No description provided for @permissionEdit.
  ///
  /// In bn, this message translates to:
  /// **'আমার ওষুধ দেখতে ও যোগ করতে পারবেন'**
  String get permissionEdit;

  /// No description provided for @inviteCodeTitle.
  ///
  /// In bn, this message translates to:
  /// **'আমন্ত্রণ কোড'**
  String get inviteCodeTitle;

  /// No description provided for @inviteCodeHelp.
  ///
  /// In bn, this message translates to:
  /// **'কোডটি আপনার পরিবারের সদস্যকে দিন। এটা একবারই, ২৪ ঘণ্টার জন্য কাজ করবে।'**
  String get inviteCodeHelp;

  /// No description provided for @shareCode.
  ///
  /// In bn, this message translates to:
  /// **'আমার ওষুধ রিমাইন্ডার আমন্ত্রণ কোড: {code}'**
  String shareCode(String code);

  /// No description provided for @iAmCaregiver.
  ///
  /// In bn, this message translates to:
  /// **'আমি কারো দেখাশোনা করি'**
  String get iAmCaregiver;

  /// No description provided for @enterInviteCode.
  ///
  /// In bn, this message translates to:
  /// **'আমন্ত্রণ কোডটি লিখুন'**
  String get enterInviteCode;

  /// No description provided for @acceptInvite.
  ///
  /// In bn, this message translates to:
  /// **'যুক্ত হোন'**
  String get acceptInvite;

  /// No description provided for @inviteInvalid.
  ///
  /// In bn, this message translates to:
  /// **'কোডটি ভুল, ব্যবহৃত অথবা মেয়াদোত্তীর্ণ।'**
  String get inviteInvalid;

  /// No description provided for @inviteOwn.
  ///
  /// In bn, this message translates to:
  /// **'নিজের কোড নিজে ব্যবহার করা যাবে না।'**
  String get inviteOwn;

  /// No description provided for @myCaregivers.
  ///
  /// In bn, this message translates to:
  /// **'যাঁরা আমার দেখাশোনা করেন'**
  String get myCaregivers;

  /// No description provided for @peopleICareFor.
  ///
  /// In bn, this message translates to:
  /// **'যাঁদের আমি দেখাশোনা করি'**
  String get peopleICareFor;

  /// No description provided for @noLinks.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কেউ নেই।'**
  String get noLinks;

  /// No description provided for @unnamedPerson.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারের সদস্য'**
  String get unnamedPerson;

  /// No description provided for @revoke.
  ///
  /// In bn, this message translates to:
  /// **'বাদ দিন'**
  String get revoke;

  /// No description provided for @revokeConfirm.
  ///
  /// In bn, this message translates to:
  /// **'{name}-কে বাদ দেবেন? তিনি আর ওষুধের তথ্য দেখতে পাবেন না।'**
  String revokeConfirm(String name);

  /// No description provided for @stateTaken.
  ///
  /// In bn, this message translates to:
  /// **'খেয়েছেন'**
  String get stateTaken;

  /// No description provided for @stateSkipped.
  ///
  /// In bn, this message translates to:
  /// **'বাদ দিয়েছেন'**
  String get stateSkipped;

  /// No description provided for @stateMissed.
  ///
  /// In bn, this message translates to:
  /// **'খাওয়া হয়নি'**
  String get stateMissed;

  /// No description provided for @stateDue.
  ///
  /// In bn, this message translates to:
  /// **'এখন খাওয়ার সময়'**
  String get stateDue;

  /// No description provided for @stateUpcoming.
  ///
  /// In bn, this message translates to:
  /// **'আসছে'**
  String get stateUpcoming;

  /// No description provided for @addForPatient.
  ///
  /// In bn, this message translates to:
  /// **'তাঁর জন্য প্রেসক্রিপশন যোগ করুন'**
  String get addForPatient;

  /// No description provided for @dashboardEmpty.
  ///
  /// In bn, this message translates to:
  /// **'আজ কোনো ডোজ নেই।'**
  String get dashboardEmpty;

  /// No description provided for @errAuthRequired.
  ///
  /// In bn, this message translates to:
  /// **'অনুগ্রহ করে আবার সাইন ইন করুন।'**
  String get errAuthRequired;

  /// No description provided for @errAuthInvalid.
  ///
  /// In bn, this message translates to:
  /// **'আপনার সেশনের মেয়াদ শেষ। আবার সাইন ইন করুন।'**
  String get errAuthInvalid;

  /// No description provided for @errRateLimited.
  ///
  /// In bn, this message translates to:
  /// **'অল্প সময়ে অনেকবার স্ক্যান করেছেন। একটু পরে আবার চেষ্টা করুন।'**
  String get errRateLimited;

  /// No description provided for @settingsTitle.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংস'**
  String get settingsTitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In bn, this message translates to:
  /// **'গোপনীয়তা নীতি'**
  String get privacyPolicy;

  /// No description provided for @privacySummary.
  ///
  /// In bn, this message translates to:
  /// **'আপনার প্রেসক্রিপশন ও ওষুধের তথ্য শুধু আপনি এবং আপনার আমন্ত্রিত পরিবারের সদস্যরা দেখতে পারেন। প্রেসক্রিপশনের ছবি কখনো সংরক্ষণ করা হয় না।'**
  String get privacySummary;

  /// No description provided for @deleteAccount.
  ///
  /// In bn, this message translates to:
  /// **'আমার অ্যাকাউন্ট মুছে দিন'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In bn, this message translates to:
  /// **'এতে আপনার অ্যাকাউন্ট, ওষুধ, ইতিহাস ও পরিবারের সংযোগ চিরতরে মুছে যাবে। এটা আর ফেরানো যাবে না।'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountButton.
  ///
  /// In bn, this message translates to:
  /// **'চিরতরে মুছে দিন'**
  String get deleteAccountButton;

  /// No description provided for @assistantTitle.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধ নিয়ে জিজ্ঞেস করুন'**
  String get assistantTitle;

  /// No description provided for @assistantHint.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন লিখুন বা বলুন'**
  String get assistantHint;

  /// No description provided for @assistantIntro.
  ///
  /// In bn, this message translates to:
  /// **'জিজ্ঞেস করতে পারেন, যেমন \"পরের ওষুধ কখন?\" আমি ডোজ বদলাতে পারি না; সেজন্য ডাক্তারকে জিজ্ঞেস করুন।'**
  String get assistantIntro;

  /// No description provided for @assistantListening.
  ///
  /// In bn, this message translates to:
  /// **'শুনছি…'**
  String get assistantListening;

  /// No description provided for @assistantVoiceUnavailable.
  ///
  /// In bn, this message translates to:
  /// **'এই ফোনে কথা বলে প্রশ্ন করা যাচ্ছে না।'**
  String get assistantVoiceUnavailable;

  /// No description provided for @call999.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯-এ ফোন করুন'**
  String get call999;

  /// No description provided for @actionStop.
  ///
  /// In bn, this message translates to:
  /// **'{name}-এর রিমাইন্ডার বন্ধ করবেন?'**
  String actionStop(String name);

  /// No description provided for @actionMealTime.
  ///
  /// In bn, this message translates to:
  /// **'{meal}-এর সময় {time} করবেন?'**
  String actionMealTime(String meal, String time);

  /// No description provided for @actionConfirm.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত করুন'**
  String get actionConfirm;

  /// No description provided for @actionDone.
  ///
  /// In bn, this message translates to:
  /// **'হয়ে গেছে'**
  String get actionDone;

  /// No description provided for @mealBreakfast.
  ///
  /// In bn, this message translates to:
  /// **'নাস্তা'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In bn, this message translates to:
  /// **'দুপুরের খাবার'**
  String get mealLunch;

  /// No description provided for @mealEvening.
  ///
  /// In bn, this message translates to:
  /// **'বিকেলের নাস্তা'**
  String get mealEvening;

  /// No description provided for @mealDinner.
  ///
  /// In bn, this message translates to:
  /// **'রাতের খাবার'**
  String get mealDinner;

  /// No description provided for @mealBedtime.
  ///
  /// In bn, this message translates to:
  /// **'ঘুম'**
  String get mealBedtime;

  /// No description provided for @refillNoticeTitle.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধ শেষ হয়ে আসছে'**
  String get refillNoticeTitle;

  /// No description provided for @refillNoticeBody.
  ///
  /// In bn, this message translates to:
  /// **'{name} প্রায় ৩ দিনের মধ্যে শেষ হবে। সময়মতো কিনে নিন।'**
  String refillNoticeBody(String name);

  /// No description provided for @lowStockTitle.
  ///
  /// In bn, this message translates to:
  /// **'শীঘ্রই শেষ হবে'**
  String get lowStockTitle;

  /// No description provided for @lowStockBody.
  ///
  /// In bn, this message translates to:
  /// **'{name}: আর প্রায় {days} দিন চলবে'**
  String lowStockBody(String name, String days);

  /// No description provided for @duplicateTitle.
  ///
  /// In bn, this message translates to:
  /// **'একই ওষুধ দুইবার?'**
  String get duplicateTitle;

  /// No description provided for @duplicateBody.
  ///
  /// In bn, this message translates to:
  /// **'{names}-এ একই উপাদান ({ingredient}) আছে। দুটোই খাওয়ার আগে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।'**
  String duplicateBody(String names, String ingredient);

  /// No description provided for @mealShiftTitle.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের সময় বদলাবেন?'**
  String get mealShiftTitle;

  /// No description provided for @mealShiftBody.
  ///
  /// In bn, this message translates to:
  /// **'{days} দিন ধরে আপনি {meal}-এর ওষুধ {to}-এর দিকে খাচ্ছেন। {meal}-এর সময় {to} করবেন?'**
  String mealShiftBody(int days, String meal, String to);

  /// No description provided for @yes.
  ///
  /// In bn, this message translates to:
  /// **'হ্যাঁ'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In bn, this message translates to:
  /// **'না'**
  String get no;

  /// No description provided for @stockTitle.
  ///
  /// In bn, this message translates to:
  /// **'হাতে কয়টা ট্যাবলেট আছে'**
  String get stockTitle;

  /// No description provided for @stockHelp.
  ///
  /// In bn, this message translates to:
  /// **'এখন হাতে কয়টা ট্যাবলেট (বা ডোজ) আছে গুনে লিখুন।'**
  String get stockHelp;

  /// No description provided for @daysLeft.
  ///
  /// In bn, this message translates to:
  /// **'আর প্রায় {days} দিন চলবে'**
  String daysLeft(String days);

  /// No description provided for @save.
  ///
  /// In bn, this message translates to:
  /// **'সংরক্ষণ'**
  String get save;

  /// No description provided for @reportTitle.
  ///
  /// In bn, this message translates to:
  /// **'গত ৭ দিন'**
  String get reportTitle;

  /// No description provided for @reportOverall.
  ///
  /// In bn, this message translates to:
  /// **'{scheduled}টি ডোজের মধ্যে {taken}টি খাওয়া হয়েছে ({percent}%)'**
  String reportOverall(int taken, int scheduled, int percent);

  /// No description provided for @reportMissed.
  ///
  /// In bn, this message translates to:
  /// **'বাদ পড়েছে: {missed} · নিজে বাদ দিয়েছেন: {skipped}'**
  String reportMissed(int missed, int skipped);

  /// No description provided for @reportShare.
  ///
  /// In bn, this message translates to:
  /// **'রিপোর্ট শেয়ার করুন (PDF)'**
  String get reportShare;

  /// No description provided for @ramadanTitle.
  ///
  /// In bn, this message translates to:
  /// **'রমজান মোড'**
  String get ramadanTitle;

  /// No description provided for @ramadanIntro.
  ///
  /// In bn, this message translates to:
  /// **'সকালের ওষুধ সেহরিতে আর সন্ধ্যার ওষুধ ইফতারে সরিয়ে নেয়।'**
  String get ramadanIntro;

  /// No description provided for @ramadanDistrict.
  ///
  /// In bn, this message translates to:
  /// **'জেলা'**
  String get ramadanDistrict;

  /// No description provided for @ramadanTimes.
  ///
  /// In bn, this message translates to:
  /// **'আজ সেহরির শেষ সময় {sehri}, ইফতার {iftar}'**
  String ramadanTimes(String sehri, String iftar);

  /// No description provided for @ramadanConflicts.
  ///
  /// In bn, this message translates to:
  /// **'এই ওষুধগুলোর ডোজ রোজার সময়ে পড়ছে। রমজানে কীভাবে খাবেন, ডাক্তারকে জিজ্ঞেস করুন:'**
  String get ramadanConflicts;

  /// No description provided for @ramadanOn.
  ///
  /// In bn, this message translates to:
  /// **'রমজানের সময়সূচি চালু করুন'**
  String get ramadanOn;

  /// No description provided for @ramadanOff.
  ///
  /// In bn, this message translates to:
  /// **'রমজানের সময়সূচি বন্ধ করুন'**
  String get ramadanOff;

  /// No description provided for @channelsHelp.
  ///
  /// In bn, this message translates to:
  /// **'কোনো ডোজ \"খেয়েছি\" চিহ্নিত না হলে: ৩০ মিনিট পরে SMS আর ৪৫ মিনিট পরে ফোন কল। এর জন্য আপনার কোনো খরচ নেই।'**
  String get channelsHelp;

  /// No description provided for @channelSms.
  ///
  /// In bn, this message translates to:
  /// **'SMS রিমাইন্ডার'**
  String get channelSms;

  /// No description provided for @channelCall.
  ///
  /// In bn, this message translates to:
  /// **'ফোন কলে রিমাইন্ডার'**
  String get channelCall;

  /// No description provided for @featurePhoneMode.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ ফোন (স্মার্টফোন নেই)'**
  String get featurePhoneMode;

  /// No description provided for @featurePhoneHelp.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিটি ডোজের সময় তাঁর ফোনে SMS বা কল যাবে; ওষুধগুলো আপনি এখান থেকে দেখাশোনা করবেন।'**
  String get featurePhoneHelp;

  /// No description provided for @trainingConsentTitle.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশন পড়া উন্নত করতে সাহায্য করুন'**
  String get trainingConsentTitle;

  /// No description provided for @trainingConsentBody.
  ///
  /// In bn, this message translates to:
  /// **'চালু থাকলে, আপনার স্ক্যান করে নিশ্চিত করা প্রেসক্রিপশনের ছবি আমাদের পাঠক উন্নত করতে ব্যবহার হবে। নাম, বয়স, ফোন নম্বর ও ঠিকানা কালো করে ঢেকে দেওয়া হয়, আর ব্যবহারের আগে একজন মানুষ প্রতিটি ছবি দেখে নেন। যেকোনো সময় বন্ধ করতে পারবেন; তখন অব্যবহৃত ছবি মুছে ফেলা হবে।'**
  String get trainingConsentBody;

  /// No description provided for @errTrainingDisabled.
  ///
  /// In bn, this message translates to:
  /// **'এখন শেয়ার করা যাচ্ছে না।'**
  String get errTrainingDisabled;

  /// No description provided for @errTrainingNotConsented.
  ///
  /// In bn, this message translates to:
  /// **'আগে সেটিংস থেকে শেয়ার করা চালু করুন।'**
  String get errTrainingNotConsented;

  /// No description provided for @errInvalidLabel.
  ///
  /// In bn, this message translates to:
  /// **'প্রেসক্রিপশনের তথ্য শেয়ার করা যায়নি।'**
  String get errInvalidLabel;

  /// No description provided for @mealTimesTitle.
  ///
  /// In bn, this message translates to:
  /// **'খাবারের সময়'**
  String get mealTimesTitle;

  /// No description provided for @mealTimesHelp.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডারের সময় এগুলো থেকে হিসাব হয়। খাবারের আগের ওষুধ ৩০ মিনিট আগে, পরের ওষুধ ১৫ মিনিট পরে মনে করানো হয়।'**
  String get mealTimesHelp;

  /// No description provided for @mealTimesSaveFailed.
  ///
  /// In bn, this message translates to:
  /// **'সময় সেভ করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।'**
  String get mealTimesSaveFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
