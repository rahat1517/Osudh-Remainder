# Prescription reader eval (2026-11-27)

- Reader: `ocr`; cloud model `claude-opus-5-5`, effort `high`
- Cases: 10 fictional printed prescriptions × clean, photo, gallery

## clean

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | 8/8 (100%) | 0 |
| strength | 26/27 (96%) | 9/9 (100%) | 0 |
| dose | 26/29 (90%) | 6/6 (100%) | 0 |
| timing | 19/28 (68%) | 5/5 (100%) | 0 |
| duration | 11/29 (38%) | 8/8 (100%) | 0 |

## photo

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 28/30 (93%) | 2/2 (100%) | 0 |
| strength | 26/27 (96%) | 2/2 (100%) | 0 |
| dose | 19/29 (66%) | — | 0 |
| timing | 20/28 (71%) | 2/2 (100%) | 0 |
| duration | 12/29 (41%) | 2/2 (100%) | 0 |

## gallery

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | — | 0 |
| strength | 26/27 (96%) | — | 0 |
| dose | 16/29 (55%) | — | 0 |
| timing | 16/28 (57%) | — | 0 |
| duration | 9/29 (31%) | — | 0 |

## Details

- WRONG (low) `rx01-basic-bangla/clean` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/clean` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/clean` **Fexo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (low) `rx01-basic-bangla/photo` **Seclo** dose: got `None`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/photo` **Seclo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (low) `rx01-basic-bangla/photo` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/photo` **Napa** timing: got `not_specified`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx01-basic-bangla/photo` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/photo` **Fexo** dose: got `None`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (low) `rx01-basic-bangla/gallery` **Seclo** dose: got `1+1`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (low) `rx01-basic-bangla/gallery` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/gallery` **Seclo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (low) `rx01-basic-bangla/gallery` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/gallery` **Napa** timing: got `not_specified`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/gallery` **Napa** duration: got `days=1 continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx01-basic-bangla/gallery` **Fexo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (medium) `rx03-continue-chronic/clean` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/clean` **Comet** timing: got `not_specified`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/clean` **Comet** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/clean` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/photo` **Comet** dose: got `None`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Comet** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/gallery` **Comet** timing: got `not_specified`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Comet** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/gallery` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx04-half-and-sos/clean` **Disopan** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG `rx04-half-and-sos/clean` **Napa Extend**: as_needed not detected
- WRONG (low) `rx04-half-and-sos/clean` **Losectil** dose: got `None`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/clean` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx04-half-and-sos/photo` **Disopan** dose: got `None`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (low) `rx04-half-and-sos/photo` **Disopan** duration: got `days=1 continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (low) `rx04-half-and-sos/photo` **Losectil** dose: got `None`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx04-half-and-sos/photo` **Losectil** timing: got `not_specified`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/photo` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx04-half-and-sos/gallery` **Disopan** dose: got `0+0.5`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (low) `rx04-half-and-sos/gallery` **Disopan** duration: got `days=2 continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG `rx04-half-and-sos/gallery` **Napa Extend**: as_needed not detected
- WRONG (medium) `rx04-half-and-sos/gallery` **Losectil** dose: got `0+1`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/gallery` **Losectil** timing: got `not_specified`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/gallery` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx05-typos/gallery` **Alatrol** duration: got `days=1 continue_indefinitely=False`, expected `{'brand': 'Alatrol', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Moxacil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Rolac** timing: got `not_specified`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Rolac** duration: got `days=2 continue_indefinitely=False`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Pantonix** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Moxacil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Rolac** timing: got `not_specified`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Rolac** duration: got `days=2 continue_indefinitely=False`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/photo` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** duration: got `days=8 continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (low) `rx06-antibiotic-tds/gallery` **Moxacil** dose: got `None`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Moxacil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx06-antibiotic-tds/gallery` **Rolac** timing: got `not_specified`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Rolac** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/gallery` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/gallery` **Pantonix** duration: got `days=8 continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (low) `rx07-no-strength/clean` **Calbo D** timing: got `not_specified`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/clean` **Calbo D** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/clean` **Ecosprin** timing: got `not_specified`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/clean` **Ecosprin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/clean` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx07-no-strength/photo` **Calbo D** name: got `CalboD ০++০  খাবারের পরে  - ০ মাস`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/photo` **Calbo D** dose: got `None`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/photo` **Calbo D** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (medium) `rx07-no-strength/photo` **Ecosprin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/photo` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx07-no-strength/gallery` **Calbo D** timing: got `not_specified`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/gallery` **Calbo D** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/gallery` **Ecosprin** timing: got `not_specified`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/gallery` **Ecosprin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx07-no-strength/gallery` **Osartil** dose: got `None`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx07-no-strength/gallery` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx08-syrup-child/clean` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- WRONG (medium) `rx08-syrup-child/clean` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/clean` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/clean`: `2. Syp. Ace Plus` (name confidence high)
- WRONG (low) `rx08-syrup-child/photo` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- WRONG (low) `rx08-syrup-child/photo` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/photo` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/photo`: `2. Syp. Ace Plus` (name confidence medium)
- WRONG (low) `rx08-syrup-child/gallery` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- WRONG (low) `rx08-syrup-child/gallery` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/gallery` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/gallery`: `2. Syp. Ace Plus` (name confidence medium)
- WRONG (medium) `rx09-four-times/clean` **Zimax** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx09-four-times/photo` **Zimax** timing: got `not_specified`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (low) `rx09-four-times/photo` **Zimax** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx09-four-times/gallery` **Zimax** timing: got `not_specified`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (low) `rx09-four-times/gallery` **Zimax** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx10-mixed/clean` **Cef-3** timing: got `not_specified`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/clean` **Cef-3** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/clean` **Angilock** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/photo` **Cef-3** timing: got `not_specified`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/photo` **Cef-3** duration: got `days=2 continue_indefinitely=False`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/gallery` **Cef-3** dose: got `None`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/gallery` **Cef-3** timing: got `not_specified`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/gallery` **Cef-3** duration: got `days=1 continue_indefinitely=False`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/gallery` **Atova** dose: got `None`, expected `{'brand': 'Atova', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx10-mixed/gallery` **Angilock** dose: got `None`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/gallery` **Angilock** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (low) `rx10-mixed/gallery` **Camlodin** dose: got `None`, expected `{'brand': 'Camlodin', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
