# ⚙️ backend/: API server ও AI agent

Python + FastAPI। প্যাকেজ ব্যবস্থাপনা [uv](https://docs.astral.sh/uv/) দিয়ে।

## চালানোর নিয়ম

```bash
cd backend
cp ../.env.example .env      # প্রথমবার, তারপর আসল মান বসান
uv sync                      # dependency install
uv run uvicorn app.main:app --reload
```

তারপর খুলুন: http://localhost:8000/health আর API ডকুমেন্টেশন http://localhost:8000/docs

## Test ও Lint

```bash
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

## API

| Endpoint | কাজ |
|---|---|
| `GET /health` | Server চালু আছে কিনা |
| `GET /drugs/search?q=maxp` | Autocomplete: brand বা generic নামে খোঁজা, ভুল বানানেও কাজ করে |
| `POST /drugs/match` `{"text": "Tab. Sec1o 20mg"}` | প্রেসক্রিপশনের একটা লাইন → সবচেয়ে কাছের ওষুধ + confidence |
| `GET /drugs/{id}` | একটা ওষুধের তথ্য |
| `POST /prescriptions/extract` (ছবি, multipart `image`) | প্রেসক্রিপশন → ওষুধের তালিকা, প্রতিটা ঘরের confidence-সহ। `ANTHROPIC_API_KEY` লাগবে, না থাকলে 503 |

### প্রেসক্রিপশন পড়ার ধাপ

```
ছবি → প্রস্তুত (ছোট করা, EXIF/GPS মোছা) → Agent ১: Claude (পড়া) → Agent ২: নিয়ম (যাচাই) → ফলাফল
```

- **Agent ১** (`app/prescriptions/reader.py`): Claude vision + structured output। নির্দেশনা `prompt.py`-তে
- **Agent ২** (`app/prescriptions/verifier.py`): AI নয়, নিয়ম। ওষুধের তালিকার সাথে মেলায়, ডোজ যাচাই করে।
  **চূড়ান্ত confidence কখনো AI-এর দেওয়া confidence-এর চেয়ে বেশি হয় না।**
- ছবি কোথাও সংরক্ষণ হয় না। রোগীর নাম/ফোনের জন্য schema-তে কোনো ঘরই নেই।
- নির্ভুলতা মাপা: [eval/README.md](eval/README.md)

`/drugs/match`-এর confidence:

| মান | মানে | অ্যাপে যা হবে |
|---|---|---|
| `high` | নাম প্রায় হুবহু, কাছাকাছি অন্য নাম নেই, শক্তি মিলেছে | নিজে পূরণ ✅ |
| `medium` | সম্ভাব্য মিল, কিন্তু নিশ্চিত নয় (টাইপো, শক্তি না মেলা) | হলুদ চিহ্ন, "এটা কি ঠিক?" |
| `low` | মিল পাওয়া যায়নি | খালি, ব্যবহারকারী বেছে নেবেন |

## কাঠামো

```
backend/
├── app/
│   ├── main.py        ← FastAPI অ্যাপ
│   ├── config.py      ← সেটিংস (.env থেকে)
│   ├── api/           ← endpoint-গুলো (health, drugs)
│   ├── drugs/         ← ওষুধের তালিকা: normalize, matcher, importer
│   └── prescriptions/ ← প্রেসক্রিপশন পাঠক (Agent ১) ও যাচাইকারী (Agent ২)
├── eval/              ← আসল AI দিয়ে নির্ভুলতা মাপা
└── tests/
```

## পরিকল্পিত অংশ (পরের phase-এ)

- Schedule Engine, rule-based (Phase 3)
- Agent ৪: বাংলা সহকারী (Phase 8)
- Agent ৫: শেখা ও পর্যবেক্ষণ (Phase 9)

> API key কখনো কোডে লিখবেন না। `.env` ফাইলে রাখুন।
