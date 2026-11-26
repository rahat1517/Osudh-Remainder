# 🌱 seed/: উন্নয়নের জন্য নমুনা ওষুধের তালিকা

> ⚠️ **`drugs_seed.csv` আসল বা যাচাই করা তালিকা নয়।**
> এটা শুধু উন্নয়ন আর test-এর জন্য প্রচলিত কিছু বাংলাদেশি brand-এর ছোট নমুনা
> (`source=dev-seed`, `verified=false`)। প্রস্তুতকারক বা শক্তি ভুল থাকতে পারে।
> **রোগীদের কাছে অ্যাপ যাওয়ার আগে এটা DGDA-র অফিসিয়াল তালিকা দিয়ে বদলাতে হবে।**

## Column

| Column | উদাহরণ | বাধ্যতামূলক |
|---|---|---|
| `brand` | Seclo | ✅ |
| `strength` | 20 mg, 500 mg + 65 mg, 120 mg/5 ml | না (যেমন ORS) |
| `generic` | Omeprazole | ✅ |
| `form` | Tablet, Capsule, Suspension | ✅ |
| `manufacturer` | Square Pharmaceuticals | না |
| `source` | dev-seed, dgda-2026 | ✅ |
| `verified` | true / false | ✅ |

## অফিসিয়াল তালিকা যোগ করার নিয়ম

1. DGDA ওয়েবসাইট থেকে নিবন্ধিত ওষুধের তালিকা (Excel/CSV) নামিয়ে ওপরের column-এ সাজান
2. ফাইলটা এখানে রাখুন, যেমন `dgda_2026.csv` (`source=dgda-2026`, `verified=true`)
3. যাচাই ও SQL তৈরি:
   ```bash
   cd backend
   uv run python -m app.drugs.importer ../database/seed/dgda_2026.csv --sql ../supabase/seed.sql
   ```
