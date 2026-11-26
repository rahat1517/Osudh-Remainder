# Contributing

## Branches

- `main` must always build and pass CI. Never commit to it directly.
- One branch per phase or feature: `phase-3-schedule-engine`, `feat/caregiver-invite`, `fix/alarm-reboot`.
- Open a pull request, wait for green CI and a review, then merge.

## Commits

Short, imperative subject line describing the change, in English:

```
Backend: add drug search endpoint
App: highlight medium-confidence fields on the confirm screen
```

## Code standards

| Area | Tools | Command |
|---|---|---|
| Backend (Python) | ruff (lint and format), pytest, Hypothesis | `uv run ruff check . && uv run ruff format . && uv run pytest` |
| App (Flutter) | `flutter_lints`, `dart format`, `flutter test` | `dart format lib test && flutter analyze && flutter test` |

- English for code, comments, documentation, tests and commit messages.
- Every feature comes with tests. Behaviour shared by the backend and the app (such as scheduling)
  is specified in `docs/` and checked by shared vectors in `spec/`.
- User-facing text lives only in the app's localization files (`app/lib/l10n/app_bn.arb`,
  `app_en.arb`). The backend returns stable error and notice **codes** with English messages for
  developers; the app maps codes to localized text.
- Wall-clock times are in the user's time zone (default `Asia/Dhaka`).

## Safety rules (mandatory)

1. Never commit real patient data or prescription images. Tests use fictional data only.
2. Secrets go in `.env` only, which is never committed.
3. The AI must never change a medicine or dose on its own.
4. No schedule is activated without the user's confirmation.
5. Every new database table has row-level security enabled.
