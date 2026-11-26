# 🗄️ database/: ওষুধের database ও ডেটা script

Supabase-এর কনফিগারেশন আর migration রাখা আছে রুটের **`supabase/`** ফোল্ডারে
(Supabase CLI ওই জায়গাটাই খোঁজে)।

## ওষুধের তালিকা (Phase 1)

```
database/seed/drugs_seed.csv   ← উৎস (CSV), এখানেই সম্পাদনা করুন
        │  importer (যাচাই + duplicate বাদ + নাম স্বাভাবিক করা)
        ▼
supabase/seed.sql              ← স্বয়ংক্রিয়ভাবে তৈরি, হাতে সম্পাদনা করবেন না
supabase/migrations/…_create_drugs.sql ← table, trigram index, RLS
```

> ⚠️ এখনকার তালিকা শুধু উন্নয়নের নমুনা (৪৬টা ওষুধ, যাচাই করা নয়)।
> বিস্তারিত ও অফিসিয়াল তালিকা যোগ করার নিয়ম: [seed/README.md](seed/README.md)

CSV বদলানোর পর SQL আবার তৈরি করুন (না করলে CI ব্যর্থ হবে):

```bash
cd backend
uv run python -m app.drugs.importer ../database/seed/drugs_seed.csv --sql ../supabase/seed.sql
```

### নিরাপত্তা

- `drugs` table সবাই **পড়তে** পারবে (এটা উন্মুক্ত তথ্য, রোগীর তথ্য নয়)
- অ্যাপ থেকে কেউ **লিখতে** পারবে না। শুধু service role (backend/importer) লিখতে পারবে

## Supabase local চালানো

[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) আর Docker লাগবে।

```bash
npx supabase start     # local database, auth, storage চালু
npx supabase status    # URL ও key দেখাবে, backend/.env-এ বসান
npx supabase stop
```

## পরিকল্পিত table

| Table | Phase |
|---|---|
| `drugs` ✅ | 1 |
| `profiles`, `prescriptions`, `medicines`, `schedules` | 4 |
| `dose_logs` | 5 |
| `caregivers`, `notifications` | 6 |
| `consents` | 11 |

প্রতিটা table-এ Row Level Security (RLS) চালু থাকবে।
