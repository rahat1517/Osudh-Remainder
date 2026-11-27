# Google Play release guide

## Build

```bash
cd app
# 1. Create an upload key once and keep it safe (not in git):
keytool -genkey -v -keystore ~/oshudh-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# 2. Create android/key.properties (git-ignored) with storeFile, storePassword, keyAlias, keyPassword
# 3. Build the bundle with production settings:
flutter build appbundle --release \
  --dart-define=BACKEND_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://xyz.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

Enable Play App Signing; upload `build/app/outputs/bundle/release/app-release.aab`.

## Store listing (draft)

**Name:** ওষুধ রিমাইন্ডার (Oshudh Reminder)

**Short description (bn):** প্রেসক্রিপশনের ছবি তুলুন, সময়মতো বাংলায় ওষুধের কথা মনে করিয়ে দেবে।
**Short description (en):** Photograph your prescription; get medicine reminders in Bangla, on time.

**Full description (en):**
Oshudh Reminder reads your prescription, lets you check every medicine, and reminds you with a
full-screen alarm and a Bangla voice when each dose is due, even without internet. Family members you
invite can see whether medicines were taken and are alerted if a dose is missed.
- Reads Bangla and English prescriptions, including 1+0+1 doses and before/after-meal instructions
- You confirm every medicine; uncertain values are highlighted
- Works offline; alarms survive restarts
- Family mode with consent and easy removal
- This app does not give medical advice.

Category: Medical. Contains ads: No. Target audience: 18+.

## Policy declarations

| Item | Answer |
|---|---|
| **Health apps declaration** | Medication reminder / adherence; not a medical device; no diagnosis |
| **Exact alarms** (`SCHEDULE_EXACT_ALARM`) | Core function: medication reminders must ring at the prescribed time; the user grants the permission in settings |
| **Full-screen intent** (`USE_FULL_SCREEN_INTENT`) | Alarm-style dose reminders over the lock screen, chosen by the user |
| **Account deletion** | In-app (Settings → Delete my account) and on request; deletes all data |
| **Privacy policy URL** | `https://oshudh-api.onrender.com/privacy` (Bangla) and `/privacy/en`, served by the backend from `docs/legal/` |

## Data safety form

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Phone number | Yes | No | Account management | No |
| Name | Yes | With invited family members | App functionality | Yes |
| Health info (medicines, dose history) | Yes | With invited family members | App functionality | No |
| Photos (prescription) | Processed, not stored | With AI service provider for processing | App functionality | Yes (manual entry) |
| Crash logs | Yes, if enabled | No | Analytics/diagnostics | — |
| Device IDs (push token) | Yes | No | App functionality | Yes |

Encrypted in transit: Yes. Users can request deletion: Yes.

## Release tracks

1. Internal testing (team devices across Xiaomi, Realme/Oppo, Samsung, Symphony/Walton)
2. Closed testing with the pilot group (see `pilot-plan.md`); 12+ testers for 14 days if required for
   new personal developer accounts
3. Production, staged rollout 10% → 50% → 100% while watching crash-free rate and alarm reliability
