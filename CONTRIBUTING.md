# 🤝 কাজের নিয়ম (Contributing)

## Branch

- `main` সবসময় চালু অবস্থায় থাকবে। সরাসরি `main`-এ commit করা যাবে না।
- প্রতিটা phase বা feature-এর জন্য আলাদা branch:
  - `phase-0-setup`, `phase-1-drug-database` …
  - ছোট কাজ: `fix/alarm-reboot`, `feat/caregiver-invite`
- কাজ শেষে Pull Request → CI সবুজ → review → merge

## Commit message

ছোট, স্পষ্ট, বাংলা বা ইংরেজিতে। প্রথম লাইনে কী বদলানো হলো:

```
Backend: ওষুধ খোঁজার API যোগ
App: confirm স্ক্রিনে হলুদ চিহ্ন
```

## কোড লেখার নিয়ম

| অংশ | নিয়ম | চালানোর কমান্ড |
|---|---|---|
| Backend (Python) | ruff (lint + format), pytest | `uv run ruff check . && uv run ruff format . && uv run pytest` |
| App (Flutter) | `flutter_lints`, `dart format` | `dart format lib test && flutter analyze && flutter test` |

- নতুন feature মানেই নতুন test।
- অ্যাপের সব লেখা `app/lib/l10n/app_bn.arb` আর `app_en.arb`-এ থাকবে। কোডে সরাসরি বাংলা লেখা বসানো যাবে না।
- সময় হিসাব সবসময় `Asia/Dhaka` ধরে।

## ⚠️ নিরাপত্তা (অবশ্যই মানতে হবে)

1. **রোগীর আসল তথ্য বা প্রেসক্রিপশনের ছবি কখনো commit করা যাবে না।** Test-এর জন্য শুধু নকল তথ্য।
2. API key, password শুধু `.env`-এ। `.env` কখনো commit হবে না।
3. AI কখনো নিজে থেকে ওষুধ বা ডোজ বদলাবে না।
4. Confirm ছাড়া কোনো schedule চালু হবে না।
5. Database-এর প্রতিটা নতুন table-এ Row Level Security (RLS) চালু থাকবে।
