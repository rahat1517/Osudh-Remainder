# App

Flutter 3.50, Android first. Languages: Bangla (default) and English. Font: Hind Siliguri.

## Run

```bash
cd app
flutter pub get
flutter run          # on a connected Android phone or emulator
```

## Test and lint

```bash
dart format lib test
flutter analyze
flutter test
```

## Layout

```
app/
├── lib/
│   ├── main.dart            App entry, locale and theme
│   ├── theme/app_theme.dart Colours, font, large touch targets
│   ├── screens/             Screens
│   ├── schedule/            Offline schedule engine (mirrors the backend; see docs/SCHEDULE_SPEC.md)
│   └── l10n/                All user-facing text: app_bn.arb (Bangla), app_en.arb (English)
├── assets/fonts/            Hind Siliguri (SIL Open Font License)
└── test/                    Widget tests, schedule conformance and parity tests
```

## Adding user-facing text

1. Add the same key to both `lib/l10n/app_bn.arb` and `app_en.arb`.
2. Run `flutter gen-l10n`.
3. Use it: `AppLocalizations.of(context).yourKey`.

Backend error and notice codes (see `backend/README.md`) are mapped to localized text here.

## Schedule engine parity

`test/schedule_conformance_test.dart` runs the shared vectors in `spec/schedule/vectors.json`.
`test/schedule_parity_test.dart` compares the Dart engine with the Python engine on random inputs:

```bash
cd ../backend && uv run python -m scripts.export_schedule_parity --out /tmp/parity.json
cd ../app && SCHEDULE_PARITY_VECTORS=/tmp/parity.json flutter test test/schedule_parity_test.dart
```

## Planned

- Onboarding, login, scan and confirm screens (Phase 4)
- Offline alarm engine and Bangla voice (Phase 5)
- Caregiver screens (Phase 6)
