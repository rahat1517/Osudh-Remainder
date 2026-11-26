# 📱 app/: Flutter মোবাইল অ্যাপ

Flutter 3.50 (Android প্রথম)। ভাষা: বাংলা (default) ও ইংরেজি। Font: Hind Siliguri।

## চালানোর নিয়ম

```bash
cd app
flutter pub get
flutter run          # সংযুক্ত Android ফোন বা emulator-এ
```

## Test ও Lint

```bash
dart format lib test
flutter analyze
flutter test
```

## কাঠামো

```
app/
├── lib/
│   ├── main.dart            ← অ্যাপের শুরু, ভাষা ও থিম
│   ├── theme/app_theme.dart ← রং, font, বড় বাটন
│   ├── screens/             ← স্ক্রিনগুলো
│   └── l10n/                ← সব লেখা: app_bn.arb (বাংলা), app_en.arb (ইংরেজি)
├── assets/fonts/            ← Hind Siliguri (SIL Open Font License)
└── test/
```

## নতুন লেখা যোগ করার নিয়ম

1. `lib/l10n/app_bn.arb` আর `app_en.arb` দুটোতেই একই key যোগ করুন
2. `flutter gen-l10n` চালান
3. কোডে ব্যবহার করুন: `AppLocalizations.of(context).yourKey`

## পরিকল্পিত অংশ

- Onboarding, লগইন, scan ও confirm স্ক্রিন (Phase 4)
- Offline alarm engine ও বাংলা voice (Phase 5)
- Caregiver স্ক্রিন (Phase 6)
