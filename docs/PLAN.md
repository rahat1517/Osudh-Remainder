# Product Plan

## 1. Problem

Many patients in Bangladesh, especially older people, miss doses or take the wrong amount.
Prescriptions are usually handwritten, mix Bangla and English, and are hard to read. Family members
who care for elderly parents often live in another city or abroad and cannot check in at dose times.

## 2. Solution

> Photograph the prescription → the app reads it → confirm with one tap →
> the app reminds you, or your parents, in Bangla when each medicine is due.

## 3. Principles

| Principle | Why |
|---|---|
| **"AI fills in, the user confirms", never "100% automatic"** | No OCR or AI reads handwriting perfectly. |
| **Alarms do not depend on AI** | Reminders are computed by deterministic code and fire offline. |
| **The AI never changes a dose** | Only a doctor changes doses. The AI may only suggest or inform. |
| **Uncertainty is surfaced, not hidden** | A wrong value marked certain is worse than an honest "please check". |

## 4. Confidence-based form filling

| Confidence | Behaviour |
|---|---|
| High (clearly printed and found in the drug catalogue) | Filled in automatically |
| Medium | Filled in, highlighted, and the user is asked to check it |
| Low or unreadable | Left empty; the user types it or picks from suggestions |
| Always | Reminders start only after the user reviews the schedule and taps **Confirm** |

## 5. Understanding Bangladeshi prescriptions

- **Dose:** `1+0+1`, `১+০+১`, `0+0+1`, `½+0+½` → morning + noon + night
- **Meal timing:** "khabarer age/pore" (before/after food), `AC`/`PC`, "before/after meal"
- **Duration:** "7 din" (7 days), "1 month", "cholbe" (continue until told otherwise)
- **Medicine names:** Bangladeshi brands (Napa, Seclo, Maxpro, …), verified against the DGDA register

## 6. Near-zero setup onboarding

```
Install → phone number (OTP read automatically) → allow notifications
        → battery settings opened for the detected phone brand
        → photograph prescription → AI reads it → Confirm
        → all reminders are scheduled
```

- Meal times are not asked up front. Defaults (breakfast 08:00, lunch 13:30, dinner 21:30) are refined
  from when the user actually taps "Taken".
- During Ramadan the app offers to move doses to sehri and iftar.

## 7. Notification escalation

```
Dose due → 1. Full-screen alarm with Bangla voice   [Taken] [Snooze] [Skip]
           ▼ no response (10 min)
           2. Snoozed alarm (up to 3 times)
           ▼ no response (30 min)
           3. SMS or automated voice call (server)
           ▼ still no response
           4. Caregiver notified
```

### Android reliability

- Exact alarms (`setExactAndAllowWhileIdle`, `SCHEDULE_EXACT_ALARM`)
- Re-register alarms on `BOOT_COMPLETED` and on time or time-zone changes
- Guide users through brand-specific battery and autostart settings (Xiaomi, Vivo, Oppo, Realme, Samsung)
- Schedules are stored on the phone, so alarms work without internet

## 8. Architecture

```
┌───────────────────────── Server ─────────────────────────┐
│ Agent 1  Prescription reader   image → structured data   │
│ Agent 2  Verifier (rules)      catalogue match, limits   │
│ Schedule engine (rules)        medicines → dose times    │
│ Agent 4  Bangla assistant      chat and voice (Phase 8)  │
│ Agent 5  Learning and monitoring (Phase 9)               │
└──────────────────────────────────────────────────────────┘
                     │ confirmed medicines
                     ▼
┌──────────────── Phone (offline, rule-based) ─────────────┐
│ Same schedule engine (Dart) + alarm scheduler            │
│ [Taken / Snooze / Skip] → synced to the server           │
└──────────────────────────────────────────────────────────┘
```

The schedule engine exists in Python and Dart. Both follow
[SCHEDULE_SPEC.md](SCHEDULE_SPEC.md) and must pass the same conformance vectors, plus a randomized
differential test that compares them on thousands of inputs in CI.

## 9. Hybrid AI strategy (cloud → self-hosted)

1. **Months 1-3:** launch on a cloud model. Every confirmation or correction by a user becomes an
   accurate label (with consent, after removing personal data).
2. **Months 3-6:** with 1,000-3,000 labels, fine-tune an open vision-language model with LoRA.
3. **Then:** the self-hosted model tries first; low-confidence cases fall back to the cloud model.

This creates a data flywheel: more use → more accurate labels → a better local model → lower cost.

## 10. MVP scope

- Phone-number login (OTP)
- Prescription upload → AI extraction → confidence form → confirm
- Medicine-name autocomplete from the drug catalogue
- Offline alarms with Bangla voice
- Taken / snooze / skip tracking
- Caregiver linking

**Version 2:** SMS and voice calls, refill reminders and pharmacy ordering, interaction warnings,
fine-tuned self-hosted model.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Misreading → wrong dose | Mandatory confirmation, confidence highlighting, catalogue verification |
| Phone kills alarms | Exact alarms, battery-settings guidance, SMS/call backup |
| Patient privacy | Encryption, consent, metadata stripping, no real data in the repository |
| Liability | Clear disclaimer; the AI never changes a dose on its own |

Detailed tasks and exit criteria per phase: [PHASES.md](PHASES.md)
