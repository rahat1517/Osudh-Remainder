# Privacy Policy

**Oshudh Reminder** · Effective date: to be set at launch · Version 1.0 (draft for legal review)

> This draft describes how the app is built today. Have it reviewed by a lawyer familiar with
> Bangladeshi law (including the Digital Security / Cyber Security legislation and any personal-data
> protection law in force at launch) before publishing.

## 1. Who we are

Oshudh Reminder ("the app", "we") helps people take their medicines on time. Contact:
[support email to be added before launch].

## 2. What we collect and why

| Data | Why | Where it is kept |
|---|---|---|
| Mobile phone number | Sign-in with a one-time code | Our authentication provider (Supabase) |
| Display name (optional) | Shown to family members you invite | Our database |
| Medicines you confirm (name, strength, dose, timing, duration) | To schedule reminders | Our database and your phone |
| Meal times | To time reminders around meals | Our database and your phone |
| Dose history (taken / skipped, with time) | Your history; alerts to family members you invite | Our database and your phone |
| Family links and invite codes | Caregiver access you grant | Our database |
| Push notification token | To deliver family alerts | Our database |
| Crash reports (optional) | To fix errors | Our error-monitoring provider, with personal data removed |

**Prescription photos** are sent to our server and to our AI provider (Anthropic) only to read the
medicines. They are **not stored** by us: the photo is processed in memory and discarded. Location and
device information embedded in the photo (EXIF, including GPS) is removed before processing. Our AI
provider processes the photo under its commercial terms and does not use API data to train its models
by default.

We do **not** collect your location, contacts, or advertising identifiers. We do not sell data and do
not show ads.

## 3. Who can see your data

- **You.**
- **Family members you invite**, only after they enter a single-use code you created, with the
  permission you chose (view, or view and add medicines). You can remove them at any time.
- **Our service providers**, only to run the service: Supabase (database and sign-in), Anthropic
  (reading prescription photos), Google Firebase (push notifications), and, if enabled, an error-monitoring
  service. They may process data outside Bangladesh.
- **Authorities**, only when required by law.

Access rules are enforced by the database itself (row-level security), not only by the app.

## 4. How long we keep data

- Account data, medicines and dose history: until you delete your account.
- Dose history on the phone: synced entries older than 90 days are removed from the phone.
- Prescription photos: not stored.
- Backups maintained by our database provider expire on its schedule.

## 5. Your choices and rights

- **Delete your account** in the app: Settings → Delete my account. This permanently deletes your
  account, medicines, history, family links and tokens.
- Stop sharing with a family member: Family → Remove.
- Ask for a copy or correction of your data: contact us.

## 6. Children

The app is meant for adults and for caregivers managing medicines for family members.

## 7. Security

Data is encrypted in transit (HTTPS). Database access is restricted per user. See
[SECURITY.md](../SECURITY.md) for technical details.

## 8. Medical disclaimer

The app reminds you to take medicines; it does not give medical advice. The AI may misread a
prescription, which is why every value must be checked and confirmed by you. Always follow your
doctor's instructions.

## 9. Changes

We will notify you in the app before material changes take effect.
