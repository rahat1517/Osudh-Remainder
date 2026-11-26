# 🗄️ database/: ওষুধের database ও ডেটা script

Supabase-এর কনফিগারেশন আর migration রাখা আছে রুটের **`supabase/`** ফোল্ডারে
(Supabase CLI ওই জায়গাটাই খোঁজে)। এই ফোল্ডারে থাকবে:

- বাংলাদেশি ওষুধের তালিকা import করার script (Phase 1)
- তথ্যের উৎস ও ব্যবহারের শর্ত সংক্রান্ত নোট

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
| `drugs` | 1 |
| `profiles`, `prescriptions`, `medicines`, `schedules` | 4 |
| `dose_logs` | 5 |
| `caregivers`, `notifications` | 6 |
| `consents` | 11 |

প্রতিটা table-এ Row Level Security (RLS) চালু থাকবে।
