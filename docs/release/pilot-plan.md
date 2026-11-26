# Pilot plan (Phase 7)

**Goal:** confirm that reminders are reliable and the confirm flow is understood by older patients,
before public release.

## Participants

20-50 people for 2-3 weeks:
- 15-30 patients aged 50+ on at least two daily medicines (diabetes, hypertension, gastric)
- Their caregivers (children living elsewhere), at least 10 pairs
- A mix of phones: Xiaomi/Redmi, Realme/Oppo, Samsung, Vivo, Symphony/Walton; Android 10-16
- Urban and semi-urban areas; both printed and handwritten prescriptions

Recruit through partner doctors or pharmacies. Obtain written informed consent (Bangla), explain that
the app is a reminder aid and that the doctor's instructions always take priority.

## Measurements

| Metric | Target | Source |
|---|---|---|
| Alarm reliability: alarms that rang within 2 minutes of the scheduled time | ≥ 99% | in-app diagnostics log + weekly check calls |
| First prescription confirmed within 3 minutes | ≥ 80% of participants | observed onboarding session |
| Fields corrected by users on the confirm screen | track per field | anonymous counts |
| Wrong values confirmed (found at check-ins) | 0 | weekly medicine review with participant |
| Crash-free sessions | ≥ 99% | crash reporting |
| Caregiver alert within 35 minutes of a missed dose | ≥ 95% | alert records vs dose logs |
| Satisfaction (would recommend) | ≥ 70% | exit survey |

## Procedure

1. **Week 0:** install, onboarding session (observe, time it), battery settings set up together
2. **Weeks 1-2:** normal use; weekly 10-minute call; collect issues
3. **Week 2-3:** fixes released to the closed track; exit survey and interview
4. Decide go / no-go for production against the targets above

## Safety

- Participants keep their usual routine (pill box, family reminders) during the pilot
- Any wrong medicine or dose found is corrected immediately, reported, and investigated
- Stop criteria: any confirmed dosing error caused by the app → pause and fix before continuing
