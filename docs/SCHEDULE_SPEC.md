# Schedule Engine Specification

**Status:** v1 · **Implementations:** `backend/app/schedule/` (Python), `app/lib/schedule/` (Dart)
**Conformance suite:** [`spec/schedule/vectors.json`](../spec/schedule/vectors.json)

The schedule engine turns a **confirmed** medicine (dose pattern, meal timing, duration) into concrete
reminder times. It is deliberately **rule-based and deterministic**: no AI is involved, and the same
input always produces the same output on the server and on the phone.

Both implementations must pass every case in the conformance suite. Any behaviour change starts with a
change to this document and the vectors, then both implementations.

---

## 1. Concepts

| Term | Meaning |
|---|---|
| **Wall-clock time** | Local time in the user's time zone (default `Asia/Dhaka`, UTC+6, no DST). All rules operate on wall-clock times; conversion to UTC happens only when an alarm is handed to the OS. |
| **Schedule day** | The calendar day a dose *belongs to*. A dose can fall after midnight (e.g. bedtime 00:30) and still belong to the previous schedule day. |
| **Slot** | A time of day: `morning`, `noon`, `evening`, `night`, or `interval` (for every-N-hours dosing). |
| **Dose time** | A slot resolved to a wall-clock time and an amount, e.g. `07:30 × 1`. |
| **Occurrence** | A dose time on a specific date: `2026-11-26T07:30 × 1`. |
| **Reminder** | One alarm. Occurrences of different medicines close together are grouped into a single reminder. |

## 2. Inputs

### 2.1 Settings (per user)

| Field | Default | Notes |
|---|---|---|
| `breakfast` | `08:00` | |
| `lunch` | `13:30` | |
| `evening` | `17:30` | Only used by four-times-a-day patterns. |
| `dinner` | `21:30` | Bangladeshi dinners are typically late. |
| `bedtime` | `22:30` | May be after midnight (e.g. `00:30`); see §3.4. |
| `offset_before_meal` | `-30` min | |
| `offset_after_meal` | `+15` min | |
| `offset_empty_stomach` | `-60` min | |
| `group_window_minutes` | `10` | §5 |
| `timezone` | `Asia/Dhaka` | |

Validation: `breakfast < lunch < evening < dinner`, all as same-day times. Violations are rejected
with error `invalid_meal_times`.

### 2.2 Medicine

| Field | Type | Notes |
|---|---|---|
| `id` | string | Opaque, chosen by the caller. |
| `dose_pattern` | string or null | `"1+0+1"` style; see §3.1. Mutually exclusive with `interval_hours`. |
| `interval_hours` | int or null | Every N hours; N must divide 24 (1, 2, 3, 4, 6, 8, 12, 24). |
| `interval_amount` | string | Amount per interval dose, default `"1"`. |
| `timing` | enum | `before_meal`, `after_meal`, `with_meal`, `empty_stomach`, `bedtime`, `not_specified`. |
| `duration_days` | int or null | 1 to 365. `null` means continue indefinitely. |
| `weekdays` | int[] or null | ISO weekdays (1 = Monday … 7 = Sunday) for weekly medicines. |
| `as_needed` | bool | SOS/PRN: never produces occurrences. |
| `start` | wall-clock datetime | Usually the moment the user confirmed the prescription. |

A medicine needs `dose_pattern` or `interval_hours` unless it is `as_needed` (`missing_dose`), and may
not have both (`conflicting_dose`). An `as_needed` medicine may carry a pattern (e.g. a daily maximum),
but never produces occurrences.

## 3. Rules

### 3.1 Dose pattern

The pattern lists the amount per slot, separated by `+` (also accepted: `-`, Bangla digits, `½ ¼ ¾`,
`a/b` fractions). It is normalised to ASCII with decimal amounts (`"½+0+½"` → `"0.5+0+0.5"`).

| Parts | Slots |
|---|---|
| 2 | morning, night |
| 3 | morning, noon, night |
| 4 | morning, noon, evening, night |

Each amount must be between 0 and 4. At least one amount must be non-zero. Otherwise
`invalid_dose_pattern`. Slots with amount 0 produce nothing.

### 3.2 Base time of a slot

| Slot | Meal |
|---|---|
| morning | breakfast |
| noon | lunch |
| evening | evening |
| night | dinner |

### 3.3 Timing offsets

The dose time is the slot's meal time plus the offset for the medicine's `timing`:

| Timing | Offset |
|---|---|
| `before_meal` | `offset_before_meal` (−30) |
| `after_meal` | `offset_after_meal` (+15) |
| `with_meal` | 0 |
| `empty_stomach` | `offset_empty_stomach` (−60) |
| `not_specified` | 0 (the meal time itself; the engine never invents a timing the doctor did not write) |
| `bedtime` | **night slot only:** the `bedtime` setting. Other slots behave as `not_specified`. |

### 3.4 After-midnight times

Times are computed in minutes from the start of the schedule day and may exceed 24:00
(e.g. dinner 23:50 + 15 = 24:05). Such a dose belongs to the schedule day but occurs at 00:05 on the
next calendar date. A `bedtime` earlier than `breakfast` (e.g. `00:30`) is treated as after midnight.

### 3.5 Interval dosing

For `interval_hours = N`, there are `24 / N` doses per schedule day at
`breakfast, breakfast + N h, breakfast + 2N h, …`, each with slot `interval` and amount
`interval_amount`. `timing` is ignored for interval dosing.

### 3.6 Weekdays

If `weekdays` is set, only schedule days whose ISO weekday is in the list produce occurrences.

### 3.7 Course length (dose-count semantics)

A course of `duration_days = D` for a daily medicine with `k` doses per day consists of exactly
**`D × k` doses**, starting with the **first dose time at or after `start`**.

This means a course confirmed in the afternoon does not lose the morning dose: a 5-day `1+0+1` course
confirmed at 15:00 delivers 10 doses, from tonight until the morning of day 6. This matches how
courses (especially antibiotics) are meant to be completed.

For weekly medicines (`weekdays` set), `duration_days` is a **calendar window** instead: all
occurrences on matching days in `[start, start date + D days)`.

`duration_days = null` continues indefinitely. `as_needed` medicines produce no occurrences.

## 4. Outputs

Per medicine:

- `doses_per_day` (per matching day for weekly medicines; 0 for as-needed)
- `daily_times`: list of `{slot, time "HH:MM", day_offset 0|1, amount}`, ordered by time
  (empty for as-needed medicines)
- `total_doses`: integer, or null when indefinite or as-needed
- `first_dose_at`, `last_dose_at`: wall-clock datetimes (null when not applicable)

And `occurrences(window_start, window_end)`: every occurrence in the half-open window, ordered by time,
then by medicine id.

## 5. Reminder grouping

Occurrences of different medicines are merged into one reminder when each is within
`group_window_minutes` of the **first** occurrence in the group. The reminder fires at the first
occurrence's time, so a dose can move **earlier** by at most the window, never later.
Occurrences at the same instant are always grouped.

## 6. Errors

| Code | When |
|---|---|
| `invalid_dose_pattern` | Pattern cannot be parsed or fails §3.1 limits |
| `invalid_interval` | `interval_hours` does not divide 24 |
| `invalid_duration` | `duration_days` outside 1–365 |
| `invalid_weekdays` | Empty list or values outside 1–7 |
| `invalid_meal_times` | §2.1 ordering violated |
| `invalid_timezone` | Unknown IANA time zone name |
| `missing_dose` | Neither pattern nor interval, and not as-needed |
| `conflicting_dose` | Both pattern and interval given |
