# 🗺️ সম্পূর্ণ কাজের পরিকল্পনা: Phase অনুযায়ী

এই ফাইলে পুরো প্রকল্প **১২টা phase**-এ ভাগ করা আছে।
প্রতিটা phase-এ লেখা আছে লক্ষ্য, কোন phase আগে শেষ হতে হবে, কাজের তালিকা, কী তৈরি হবে আর কখন phase "শেষ" ধরা হবে।

> **কাজের নিয়ম:** আপনি বলবেন *"Phase X শুরু করো"*। আমি সেই phase-এর কাজ করব,
> আলাদা branch-এ commit করব, আর শেষে "শেষের শর্ত"-গুলো যাচাই করে রিপোর্ট দেব।

---

## 📌 সারসংক্ষেপ

| Phase | নাম | অংশ | আনুমানিক সময় |
|---|---|---|---|
| **0** | ভিত্তি ও Setup | সব | ১ সপ্তাহ |
| **1** | বাংলাদেশি ওষুধের Database | database, backend | ১–২ সপ্তাহ |
| **2** | প্রেসক্রিপশন পাঠক ও যাচাইকারী (AI) | backend | ২–৩ সপ্তাহ |
| **3** | Schedule Engine | backend, app | ১ সপ্তাহ |
| **4** | মোবাইল অ্যাপ: Onboarding ও Scan-Confirm | app | ২–৩ সপ্তাহ |
| **5** | Offline Alarm Engine ও বাংলা Voice | app | ২ সপ্তাহ |
| **6** | Caregiver Mode | app, backend | ১–২ সপ্তাহ |
| **7** | পরীক্ষা, Pilot ও Play Store | সব | ২–৩ সপ্তাহ |
| | 🚀 **MVP লঞ্চ** | | **মোট ~৩–৪ মাস** |
| **8** | বাংলা AI সহকারী | backend, app | ২ সপ্তাহ |
| **9** | শেখা, Refill ও রমজান মোড | backend, app | ২ সপ্তাহ |
| **10** | SMS ও Voice Call Escalation | backend | ১–২ সপ্তাহ |
| **11** | Data Flywheel ও Local LLM (Hybrid) | ml, backend | ৪–৬ সপ্তাহ |

(সময়গুলো একজন developer আর আমার সহায়তা ধরে অনুমান করা। আসল সময় কম-বেশি হতে পারে।)

```
0 ──► 1 ──► 2 ──► 3 ──► 4 ──► 5 ──► 6 ──► 7 🚀
                              │
                              └──► 8 ──► 9 ──► 10 ──► 11
```

---

## 🧱 প্রযুক্তিগত সিদ্ধান্ত (Phase 0-এ চূড়ান্ত হবে)

| বিষয় | প্রস্তাবিত (default) | কারণ |
|---|---|---|
| মোবাইল অ্যাপ | **Flutter** (আগে Android, পরে iOS) | এক কোডে দুই প্ল্যাটফর্ম। বাংলাদেশে বেশিরভাগ ফোন Android |
| Backend | **Python + FastAPI** | AI আর ML-এর কাজ Python-এ সবচেয়ে সহজ। `ml/`-এর সাথে একই ভাষা থাকবে |
| Database ও Auth | **Supabase** (PostgreSQL, Phone OTP, Storage) | বিনামূল্যে শুরু করা যায়, RLS দিয়ে নিরাপত্তা |
| প্রেসক্রিপশন পড়া | **Claude API** (vision + structured output) | হাতের লেখা পড়ায় শক্তিশালী। পরে hybrid |
| Schedule হিসাব | **Rule-based কোড, AI নয়** | সময় হিসাবে ভুল হওয়া চলবে না, তাই নির্দিষ্ট নিয়মে চলবে |
| অ্যালার্ম | Android AlarmManager (local) | Offline, নির্ভরযোগ্য |
| Push notification | Firebase Cloud Messaging (FCM) | Caregiver alert-এর জন্য |
| Backend hosting | Railway / Render / Fly.io | শুরুতে সস্তা |

> ⚠️ **গুরুত্বপূর্ণ সংশোধন:** আগের আলোচনায় Agent ৩ (Schedule) AI ছিল।
> নিরাপত্তার জন্য এটা **rule-based** করা হলো। AI শুধু নির্দেশনা পড়বে (`১+০+১`, "খাবারের আগে"),
> আর সময় হিসাব করবে নির্দিষ্ট নিয়মের কোড, যেটা test দিয়ে ১০০% যাচাই করা যায়।

---

## Phase 0: ভিত্তি ও Setup

**লক্ষ্য:** সব অংশের খালি কিন্তু চালু হওয়া কাঠামো, যাতে পরের phase-গুলো সরাসরি শুরু করা যায়।
**নির্ভরতা:** নেই

### কাজ
- [ ] GitHub repository-তে push, `main` branch সুরক্ষা
- [ ] Backend: FastAPI প্রকল্প (`backend/`), `/health` endpoint, settings (`.env` পড়া)
- [ ] Backend: test setup (pytest), lint (ruff)
- [ ] App: `flutter create` দিয়ে প্রকল্প (`app/`), বাংলা font (Hind Siliguri / Noto Sans Bengali), থিম
- [ ] App: বাংলা/ইংরেজি localization কাঠামো (বাংলা default)
- [ ] Supabase: প্রকল্প তৈরি, local dev setup (`supabase/` ফোল্ডার)
- [ ] GitHub Actions CI: backend test + lint, Flutter analyze + test
- [ ] `CONTRIBUTING.md`: branch, commit, কোড লেখার নিয়ম

### যা তৈরি হবে
চালু হওয়া backend server, খালি Flutter অ্যাপ (বাংলা স্বাগত স্ক্রিন), Supabase প্রকল্প, সবুজ CI

### শেষের শর্ত
- `GET /health` → `{"status": "ok"}`
- Flutter অ্যাপ emulator-এ বাংলা লেখাসহ চালু হয়
- CI-তে সব check পাস করে

---

## Phase 1: বাংলাদেশি ওষুধের Database

**লক্ষ্য:** প্রেসক্রিপশনের ওষুধের নাম যাচাই আর autocomplete-এর জন্য নির্ভরযোগ্য database।
**নির্ভরতা:** Phase 0

### কাজ
- [ ] Database schema: `drugs` (brand, generic, strength, form, manufacturer, DAR নম্বর)
- [ ] তথ্যের উৎস ঠিক করা (DGDA তালিকা / উন্মুক্ত তথ্য), ব্যবহারের অনুমতি ও শর্ত যাচাই
- [ ] Import script: CSV → PostgreSQL (পরিষ্কার, duplicate বাদ, নাম স্বাভাবিক করা)
- [ ] খোঁজার পদ্ধতি: `pg_trgm` দিয়ে fuzzy search ("Ma?x" → "Maxpro 20")
- [ ] বানানের ভুল ও প্রচলিত সংক্ষেপ সামলানো (যেমন "Napa Ext" = "Napa Extend")
- [ ] API: `GET /drugs/search?q=` (autocomplete), `POST /drugs/match` (সবচেয়ে কাছের মিল + score)
- [ ] Test: পরিচিত ৫০টা ভুল বানান → সঠিক ওষুধ

### যা তৈরি হবে
ওষুধের database, search আর match API

### শেষের শর্ত
- কমপক্ষে প্রচলিত ১,০০০+ brand আছে
- ভুল বানানের test set-এ ≥ ৯০% সঠিক মিল
- Search response < ২০০ms

---

## Phase 2: প্রেসক্রিপশন পাঠক ও যাচাইকারী (AI)

**লক্ষ্য:** ছবি থেকে ওষুধের তালিকা, প্রতিটা ঘরের confidence-সহ। এটাই প্রকল্পের মূল অংশ।
**নির্ভরতা:** Phase 1

### কাজ
- [ ] Output schema ঠিক করা: name, strength, dose pattern, timing, duration, instructions, confidence (প্রতিটা ঘরের জন্য আলাদা)
- [ ] **Agent ১ (পাঠক):** Claude vision + structured output দিয়ে ছবি → JSON
- [ ] বাংলাদেশি নির্দেশনার নিয়ম prompt-এ: `১+০+১`, `½+0+½`, `AC/PC`, `খাবারের আগে/পরে`, `চলবে`, বাংলা সংখ্যা
- [ ] **Agent ২ (যাচাইকারী):** প্রতিটা নাম Phase 1-এর database-এর সাথে মেলানো, confidence ঠিক করা
- [ ] চূড়ান্ত confidence-এর নিয়ম: AI-এর নিশ্চয়তা + database-এ মিল + ঘরের ধরন মিলিয়ে উচ্চ / মাঝারি / কম
- [ ] ছবির মান যাচাই: ঝাপসা, অন্ধকার বা প্রেসক্রিপশন নয় এমন ছবি → "আবার তুলুন"
- [ ] ছবি থেকে রোগীর নাম/ফোন নম্বর সংরক্ষণ না করা (শুধু ওষুধের তথ্য রাখা)
- [ ] API: `POST /prescriptions/extract` (ছবি → ফলাফল)
- [ ] **মূল্যায়ন set (eval):** ৫০–১০০টা নকল বা অনুমতিপ্রাপ্ত প্রেসক্রিপশন + সঠিক উত্তর
- [ ] মূল্যায়ন script: ঘর অনুযায়ী নির্ভুলতা মাপা

### যা তৈরি হবে
Extraction API, eval set, নির্ভুলতার রিপোর্ট

### শেষের শর্ত
- ছাপা প্রেসক্রিপশনে ওষুধের নাম ≥ ৯৫%, ডোজ ≥ ৯৫% সঠিক
- হাতে লেখা প্রেসক্রিপশনে সব "উচ্চ" confidence ঘর ≥ ৯৮% সঠিক
- ভুল পড়া ঘরের বেশিরভাগ "মাঝারি" বা "কম" হিসেবে চিহ্নিত হয় (ভুল কিন্তু "উচ্চ", এমন ঘর খুব কম)

> **মনে রাখবেন:** এখানে মূল লক্ষ্য সবকিছু সঠিক পড়া নয়, বরং **ভুল হলে সেটা ধরা পড়া**।

---

## Phase 3: Schedule Engine

**লক্ষ্য:** confirm করা ওষুধের তালিকা থেকে নির্ভুল অ্যালার্মের সময়সূচি।
**নির্ভরতা:** Phase 2

### কাজ
- [ ] Dose parser: `1+0+1`, `১+১+১`, `0+0+½`, `1+1+1+1`, "দিনে ২ বার", "প্রতি ৮ ঘণ্টা"
- [ ] খাবারের সময় + আগে/পরে → নির্দিষ্ট সময় (default: আগে = −৩০ মিনিট, পরে = +১৫ মিনিট)
- [ ] মেয়াদ: শুরুর তারিখ + দিন → শেষ তারিখ; "চলবে" → শেষ তারিখ নেই
- [ ] বিশেষ ক্ষেত্র: "সপ্তাহে ১ দিন", "প্রয়োজনে (SOS)" (অ্যালার্ম নয়, তালিকায় থাকবে)
- [ ] কাছাকাছি সময়ের ওষুধ একসাথে করা ("রাত ৯টা: Seclo + Napa")
- [ ] একই কোড Dart-এ (app) চলবে যাতে offline-এ schedule আবার হিসাব করা যায়, অথবা backend থেকে তৈরি schedule ফোনে সংরক্ষণ
- [ ] বিস্তারিত unit test (২০০+ ক্ষেত্র)

### যা তৈরি হবে
Schedule engine library + `POST /schedules/generate`

### শেষের শর্ত
- সব test পাস (১০০%, কারণ এটা rule-based)
- সময় অঞ্চল: Asia/Dhaka নিশ্চিত

---

## Phase 4: মোবাইল অ্যাপ (Onboarding ও Scan-Confirm)

**লক্ষ্য:** ব্যবহারকারী অ্যাপ install করে প্রেসক্রিপশন confirm পর্যন্ত যেতে পারবেন।
**নির্ভরতা:** Phase 2, 3

### কাজ
- [ ] Database schema: `profiles`, `prescriptions`, `medicines`, `schedules` + RLS
- [ ] ফোন নম্বর লগইন (Supabase Phone OTP, Android-এ OTP auto-read)
- [ ] Onboarding: স্বাগত → লগইন → permission → প্রথম প্রেসক্রিপশন
- [ ] Camera / gallery থেকে প্রেসক্রিপশন, ছবি crop আর মান ঠিক করা
- [ ] **Confirm স্ক্রিন:** ✅ উচ্চ, 🟡 মাঝারি (হলুদ), ⬜ কম (খালি) → সম্পাদনা → "ঠিক আছে"
- [ ] ওষুধের নাম autocomplete (Phase 1 API)
- [ ] হাতে ওষুধ যোগ করার স্ক্রিন (প্রেসক্রিপশন ছাড়া)
- [ ] হোম স্ক্রিন: আজকের ওষুধ, পরের ডোজ
- [ ] ওষুধের তালিকা, সম্পাদনা, বন্ধ করা
- [ ] বড় font, বড় বাটন, সহজ বাংলা (বয়স্কদের কথা মাথায় রেখে)

### যা তৈরি হবে
Scan থেকে confirm পর্যন্ত কাজ করা অ্যাপ (অ্যালার্ম ছাড়া)

### শেষের শর্ত
- নতুন ব্যবহারকারী ৩ মিনিটের মধ্যে প্রথম প্রেসক্রিপশন confirm করতে পারেন
- Confirm না করে schedule তৈরি হয় না
- একজন ব্যবহারকারী অন্যজনের তথ্য দেখতে পারেন না (RLS test)

---

## Phase 5: Offline Alarm Engine ও বাংলা Voice

**লক্ষ্য:** ইন্টারনেট ছাড়াই, ফোন lock থাকলেও, সময়মতো অ্যালার্ম বাজবে।
**নির্ভরতা:** Phase 4

### কাজ
- [ ] Schedule ফোনে local-ভাবে সংরক্ষণ (SQLite / Drift)
- [ ] Exact alarm: `setExactAndAllowWhileIdle`, `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`
- [ ] Full-screen অ্যালার্ম স্ক্রিন (lock screen-এর ওপরে): ওষুধের নাম, ছবি, কয়টা
- [ ] বাটন: ✅ খেয়েছি / ⏰ ১০ মিনিট পরে / ❌ বাদ
- [ ] Snooze (সর্বোচ্চ ৩ বার)
- [ ] বাংলা voice (TTS): "এখন আপনার Seclo 20, একটা, খাবারের আগে খাওয়ার সময়"
- [ ] `BOOT_COMPLETED`, সময় বা timezone বদলালে অ্যালার্ম আবার set করা
- [ ] ব্র্যান্ড চিনে battery / autostart গাইড (Xiaomi, Vivo, Oppo, Realme, Samsung, অন্যান্য)
- [ ] Dose log (`dose_logs`): local-এ সংরক্ষণ, ইন্টারনেট এলে server-এ sync
- [ ] কয়েকটা আসল ফোনে পরীক্ষা (বিশেষ করে Xiaomi / Realme)

### যা তৈরি হবে
নির্ভরযোগ্য অ্যালার্ম ব্যবস্থা + dose tracking

### শেষের শর্ত
- Airplane mode-এ, ফোন lock অবস্থায়, ৮ ঘণ্টা পরেও অ্যালার্ম ঠিক সময়ে বাজে
- Restart-এর পরেও অ্যালার্ম থাকে
- কমপক্ষে ৩টা ভিন্ন ব্র্যান্ডের ফোনে পরীক্ষিত

---

## Phase 6: Caregiver Mode

**লক্ষ্য:** পরিবারের সদস্য রোগীর schedule দেখবেন আর মিস হলে খবর পাবেন।
**নির্ভরতা:** Phase 5

### কাজ
- [ ] `caregivers` schema: রোগী ↔ caregiver সম্পর্ক, অনুমতির ধরন (শুধু দেখা / সম্পাদনা)
- [ ] আমন্ত্রণ: কোড বা লিংক দিয়ে যুক্ত হওয়া, রোগীর সম্মতি নেওয়া
- [ ] Caregiver ড্যাশবোর্ড: আজ কোন ডোজ খাওয়া হলো, কোনটা মিস
- [ ] Caregiver রোগীর হয়ে প্রেসক্রিপশন যোগ করতে পারবেন (বয়স্কদের জন্য)
- [ ] মিস হলে push notification (FCM): ৩০ মিনিটের মধ্যে "খেয়েছি" না এলে
- [ ] Server-side মিস শনাক্তকরণ (নির্দিষ্ট সময় পরপর চলা job)
- [ ] সম্পর্ক বাতিল করার সুবিধা

### যা তৈরি হবে
Caregiver linking, ড্যাশবোর্ড, মিস-ডোজ alert

### শেষের শর্ত
- রোগীর ডোজ মিস হলে ৩৫ মিনিটের মধ্যে caregiver notification পান
- সম্মতি ছাড়া কেউ কারো তথ্য দেখতে পারেন না

---

## Phase 7: পরীক্ষা, Pilot ও Play Store

**লক্ষ্য:** আসল ব্যবহারকারীদের দিয়ে পরীক্ষা করে নিরাপদভাবে বাজারে আনা।
**নির্ভরতা:** Phase 6

### কাজ
- [ ] পুরো flow-এর end-to-end test
- [ ] নিরাপত্তা পর্যালোচনা: RLS, API auth, rate limit, key ব্যবস্থাপনা
- [ ] Privacy Policy ও Terms (বাংলা + ইংরেজি), চিকিৎসা disclaimer
- [ ] অ্যাপে তথ্য মুছে ফেলার সুবিধা (account delete)
- [ ] Crash reporting (Sentry / Firebase Crashlytics), basic analytics (ব্যক্তিগত তথ্য ছাড়া)
- [ ] **Pilot:** ২০–৫০ জন ব্যবহারকারী (বয়স্ক + caregiver), ২–৩ সপ্তাহ
- [ ] Pilot-এর মতামত থেকে সংশোধন
- [ ] Play Store: Health app declaration, exact alarm-এর কারণ ব্যাখ্যা, screenshot, বাংলা বর্ণনা
- [ ] Internal → Closed testing → Production release

### যা তৈরি হবে
🚀 **MVP Play Store-এ**

### শেষের শর্ত
- Pilot-এ অ্যালার্ম নির্ভরযোগ্যতা ≥ ৯৯%
- Crash-free session ≥ ৯৯%
- Play Store review পাস

---

## Phase 8: বাংলা AI সহকারী

**লক্ষ্য:** কথা বলে বা লিখে ওষুধের তথ্য জানা আর রিমাইন্ডার বদলানো।
**নির্ভরতা:** Phase 7

### কাজ
- [ ] চ্যাট স্ক্রিন (বাংলা লেখা)
- [ ] Voice input (বাংলা STT) + voice উত্তর (TTS)
- [ ] AI-এর tool: "আজকের schedule দেখাও", "ওষুধ বন্ধ করো" (confirm সহ), "সময় বদলাও" (confirm সহ)
- [ ] **নিরাপত্তার নিয়ম:** ডোজ বদলানো বা "মিস হলে দুটো খাবো?" ধরনের প্রশ্নে → ডাক্তার/ফার্মাসিস্টের কাছে পাঠানো
- [ ] জরুরি লক্ষণ শনাক্ত করে (বুকে ব্যথা, শ্বাসকষ্ট ইত্যাদি) → ৯৯৯ / নিকটস্থ হাসপাতালে যাওয়ার পরামর্শ
- [ ] কথোপকথনের eval: ১০০টা প্রশ্ন + নিরাপদ উত্তরের মানদণ্ড

### শেষের শর্ত
- নিরাপত্তা eval-এ ১০০% (কখনো নিজে ডোজ পরামর্শ দেয় না)
- প্রচলিত প্রশ্নে ≥ ৯০% সঠিক উত্তর

---

## Phase 9: শেখা, Refill ও রমজান মোড

**লক্ষ্য:** অ্যাপ ব্যবহারকারীর অভ্যাস থেকে শিখবে আর আগে থেকে সাহায্য করবে।
**নির্ভরতা:** Phase 7

### কাজ
- [ ] সময় শেখা: ৩+ দিন একই রকম দেরি হলে সময় বদলানোর প্রস্তাব
- [ ] Refill: ওষুধের পরিমাণ ট্র্যাক → শেষ হওয়ার ৩ দিন আগে সতর্কতা
- [ ] রমজান মোড: সেহরি/ইফতারের সময় (এলাকা অনুযায়ী) → schedule বদলানোর প্রস্তাব
- [ ] সাপ্তাহিক রিপোর্ট (adherence %), ডাক্তারকে দেখানোর জন্য PDF
- [ ] একই generic দুই প্রেসক্রিপশনে থাকলে সতর্কতা (duplicate therapy)

### শেষের শর্ত
- সব প্রস্তাব ব্যবহারকারীর "হ্যাঁ" ছাড়া কার্যকর হয় না
- রমজান মোড পরীক্ষিত (ঢাকা, চট্টগ্রাম, সিলেটের সময়)

---

## Phase 10: SMS ও Voice Call Escalation

**লক্ষ্য:** ইন্টারনেট বা smartphone ছাড়া ব্যবহারকারীদের কাছেও পৌঁছানো।
**নির্ভরতা:** Phase 7

### কাজ
- [ ] বাংলাদেশি SMS gateway নির্বাচন ও integration
- [ ] Automated voice call (রেকর্ড করা বাংলা বার্তা)
- [ ] Escalation নিয়ম: অ্যালার্ম → ৩০ মিনিট → SMS/call → caregiver
- [ ] Feature phone মোড: caregiver schedule set করবেন, রোগী শুধু call/SMS পাবেন
- [ ] খরচ নিয়ন্ত্রণ: দৈনিক সীমা, premium feature হিসেবে রাখা
- [ ] Opt-in / opt-out

### শেষের শর্ত
- SMS ও call ঠিক সময়ে পৌঁছায় (≥ ৯৫%)
- প্রতি ব্যবহারকারীর মাসিক খরচ হিসাব ও নিয়ন্ত্রিত

---

## Phase 11: Data Flywheel ও Local LLM (Hybrid)

**লক্ষ্য:** নিজের fine-tuned model দিয়ে খরচ কমানো আর নির্ভুলতা বাড়ানো।
**নির্ভরতা:** Phase 7 + যথেষ্ট data (১,০০০–৩,০০০ confirm করা প্রেসক্রিপশন)

### কাজ
- [ ] সম্মতি ব্যবস্থা: "আমার প্রেসক্রিপশন অ্যাপ উন্নত করতে ব্যবহার করা যাবে" (opt-in)
- [ ] ব্যক্তিগত তথ্য মোছা (নাম, ফোন, ঠিকানা): ছবিতে blur + লেখায় মুছে ফেলা
- [ ] Label pipeline: ব্যবহারকারীর confirm করা ফলাফল → training data
- [ ] Train / validation / test ভাগ (একই ডাক্তারের প্রেসক্রিপশন একই ভাগে)
- [ ] Open-source vision model (যেমন Qwen2.5-VL 7B) + LoRA/QLoRA fine-tune
- [ ] Phase 2-এর eval-এ cloud AI-এর সাথে তুলনা
- [ ] Self-hosted inference (vLLM) + hybrid router: local আগে, confidence কম হলে cloud
- [ ] Model version ও পর্যবেক্ষণ: নির্ভুলতা কমলে সতর্কতা

### শেষের শর্ত
- Local model-এর "উচ্চ" confidence ঘরের নির্ভুলতা cloud-এর সমান বা বেশি
- কমপক্ষে ৬০% প্রেসক্রিপশন শুধু local model দিয়ে সমাধান হয়
- প্রতি প্রেসক্রিপশনে গড় খরচ কমে

---

## 🗄️ Database-এর রূপরেখা (Phase অনুযায়ী তৈরি হবে)

| Table | উদ্দেশ্য | Phase |
|---|---|---|
| `drugs` | বাংলাদেশি ওষুধের তালিকা | 1 |
| `profiles` | ব্যবহারকারী (নাম, ফোন, ভাষা, খাবারের সময়) | 4 |
| `prescriptions` | আপলোড করা প্রেসক্রিপশন (ছবি encrypted storage-এ) | 4 |
| `medicines` | confirm করা ওষুধ (নাম, ডোজ, সময়, মেয়াদ) | 4 |
| `schedules` | প্রতিটা অ্যালার্মের সময় | 4 |
| `dose_logs` | খেয়েছি / বাদ / মিস | 5 |
| `caregivers` | রোগী ↔ caregiver সম্পর্ক | 6 |
| `notifications` | পাঠানো alert/SMS/call-এর রেকর্ড | 6, 10 |
| `consents` | data ব্যবহারের সম্মতি | 11 |

---

## 🔁 প্রতিটা Phase-এর কাজের ধারা

1. `phase-X-নাম` branch তৈরি
2. কাজের তালিকা অনুযায়ী কোড + test
3. ছোট ছোট commit
4. শেষের শর্ত যাচাই
5. আপনাকে রিপোর্ট: কী হলো, কী বাকি, কোন সমস্যা
6. আপনার অনুমতি পেলে `main`-এ merge (Pull Request)

---

## ❓ শুরুর আগে আপনার সিদ্ধান্ত লাগবে

| প্রশ্ন | Default (আপনি না বললে) |
|---|---|
| Backend ভাষা | Python + FastAPI |
| অ্যাপের নাম | "ওষুধ রিমাইন্ডার" (পরে বদলানো যাবে) |
| প্রথমে শুধু Android? | হ্যাঁ |
| Supabase account | আপনাকে বানাতে হবে (বিনামূল্যে) |
| Claude API key | আপনাকে console.anthropic.com থেকে নিতে হবে (Phase 2-এর আগে) |
