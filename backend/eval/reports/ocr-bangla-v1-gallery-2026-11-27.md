# Prescription reader eval (2026-11-27)

- Reader: `ocr`
- Cases: 10 fictional printed prescriptions × clean, photo, gallery

## clean

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | 24/24 (100%) | 0 |
| strength | 26/27 (96%) | 23/23 (100%) | 0 |
| dose | 25/29 (86%) | 17/17 (100%) | 0 |
| timing | 25/28 (89%) | 13/13 (100%) | 0 |
| duration | 26/29 (90%) | 24/24 (100%) | 0 |

## photo

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | 10/10 (100%) | 0 |
| strength | 26/27 (96%) | 8/8 (100%) | 0 |
| dose | 26/29 (90%) | 6/6 (100%) | 0 |
| timing | 25/28 (89%) | 7/7 (100%) | 0 |
| duration | 25/29 (86%) | 8/8 (100%) | 0 |

## gallery

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | — | 0 |
| strength | 26/27 (96%) | — | 0 |
| dose | 23/29 (79%) | — | 0 |
| timing | 21/28 (75%) | — | 0 |
| duration | 22/29 (76%) | — | 0 |

## Details

- WRONG (medium) `rx01-basic-bangla/clean` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/gallery` **Seclo** dose: got `0+1`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/gallery` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/gallery` **Napa** timing: got `not_specified`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx03-continue-chronic/photo` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/photo` **Rosuva** dose: got `None`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/gallery` **Amdocal** dose: got `None`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Comet** timing: got `not_specified`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/gallery` **Rosuva** dose: got `None`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG `rx04-half-and-sos/clean` **Napa Extend**: as_needed not detected
- WRONG (low) `rx04-half-and-sos/clean` **Losectil** dose: got `None`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/clean` **Losectil** timing: got `not_specified`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG `rx04-half-and-sos/photo` **Napa Extend**: as_needed not detected
- WRONG (medium) `rx04-half-and-sos/gallery` **Disopan** duration: got `days=25 continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG `rx04-half-and-sos/gallery` **Napa Extend**: as_needed not detected
- WRONG (medium) `rx04-half-and-sos/gallery` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Pantonix** duration: got `days=18 continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** duration: got `days=18 continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx06-antibiotic-tds/gallery` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Pantonix** duration: got `days=18 continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx07-no-strength/clean` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx07-no-strength/gallery` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx08-syrup-child/clean` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/clean` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/clean`: `2. Syp. Ace Plus 1` (name confidence low)
- WRONG (low) `rx08-syrup-child/photo` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/photo` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/photo`: `2. Syp. Ace Plus` (name confidence high)
- WRONG (low) `rx08-syrup-child/gallery` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/gallery` **Orsaline-N**: not found
- WRONG (medium) `rx09-four-times/gallery` **Zimax** timing: got `not_specified`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
