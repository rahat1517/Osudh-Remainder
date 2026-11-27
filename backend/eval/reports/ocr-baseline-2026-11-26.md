# Prescription reader eval (2026-11-26)

- Reader: `ocr`
- Cases: 10 fictional printed prescriptions × clean, photo

## clean

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | 13/13 (100%) | 0 |
| strength | 25/27 (93%) | 12/12 (100%) | 0 |
| dose | 9/29 (31%) | 4/4 (100%) | 0 |
| timing | 16/28 (57%) | 6/6 (100%) | 0 |
| duration | 9/29 (31%) | 9/9 (100%) | 0 |

## photo

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 28/30 (93%) | 10/10 (100%) | 0 |
| strength | 24/27 (89%) | 8/8 (100%) | 0 |
| dose | 9/29 (31%) | 3/3 (100%) | 0 |
| timing | 15/28 (54%) | 5/5 (100%) | 0 |
| duration | 9/29 (31%) | 9/9 (100%) | 0 |

## Details

- WRONG (low) `rx01-basic-bangla/clean` **Seclo** dose: got `None`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/clean` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/clean` **Seclo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (low) `rx01-basic-bangla/clean` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx01-basic-bangla/clean` **Napa** timing: got `not_specified`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx01-basic-bangla/clean` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/clean` **Fexo** dose: got `None`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (medium) `rx01-basic-bangla/clean` **Fexo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (low) `rx01-basic-bangla/photo` **Seclo** dose: got `None`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/photo` **Seclo** timing: got `not_specified`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (medium) `rx01-basic-bangla/photo` **Seclo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Seclo', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 30}`
- WRONG (low) `rx01-basic-bangla/photo` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/photo` **Napa** timing: got `not_specified`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx01-basic-bangla/photo` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx01-basic-bangla/photo` **Fexo** dose: got `None`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (medium) `rx01-basic-bangla/photo` **Fexo** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Fexo', 'strength': '120 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'days': 10}`
- WRONG (medium) `rx02-latin-abbreviations/photo` **Sergel** timing: got `not_specified`, expected `{'brand': 'Sergel', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx02-latin-abbreviations/photo` **Ciprocin** name: got `Ciprocin500 1BD PC x7days`, expected `{'brand': 'Ciprocin', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx02-latin-abbreviations/photo` **Ciprocin** strength: got `None`, expected `{'brand': 'Ciprocin', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx03-continue-chronic/clean` **Amdocal** dose: got `None`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/clean` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/clean` **Comet** dose: got `None`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/clean` **Comet** timing: got `not_specified`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/clean` **Comet** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/clean` **Rosuva** dose: got `None`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/clean` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/photo` **Amdocal** dose: got `None`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Amdocal** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Amdocal', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/photo` **Comet** dose: got `None`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Comet** timing: got `not_specified`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Comet** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Comet', 'strength': '500 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx03-continue-chronic/photo` **Rosuva** dose: got `0+0+4`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx03-continue-chronic/photo` **Rosuva** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rosuva', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx04-half-and-sos/clean` **Disopan** dose: got `2+0+0.5`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (medium) `rx04-half-and-sos/clean` **Disopan** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (low) `rx04-half-and-sos/clean` **Losectil** dose: got `None`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/clean` **Losectil** timing: got `not_specified`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/clean` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx04-half-and-sos/photo` **Disopan** dose: got `None`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (medium) `rx04-half-and-sos/photo` **Disopan** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Disopan', 'strength': '0.5 mg', 'dose': '0.5+0+0.5', 'timing': 'not_specified', 'days': 15}`
- WRONG (low) `rx04-half-and-sos/photo` **Losectil** dose: got `None`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (low) `rx04-half-and-sos/photo` **Losectil** timing: got `not_specified`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx04-half-and-sos/photo` **Losectil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Losectil', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'empty_stomach', 'days': 30}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Moxacil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Rolac** dose: got `None`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Rolac** timing: got `not_specified`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Rolac** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/clean` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/clean` **Pantonix** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Moxacil** timing: got `not_specified`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Moxacil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Moxacil', 'strength': '500 mg', 'dose': '1+1+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx06-antibiotic-tds/photo` **Rolac** dose: got `None`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Rolac** timing: got `not_specified`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Rolac** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Rolac', 'strength': '10 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 5}`
- WRONG (low) `rx06-antibiotic-tds/photo` **Pantonix** dose: got `None`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** timing: got `not_specified`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (medium) `rx06-antibiotic-tds/photo` **Pantonix** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Pantonix', 'strength': '20 mg', 'dose': '1+0+1', 'timing': 'before_meal', 'days': 14}`
- WRONG (low) `rx07-no-strength/clean` **Calbo D** dose: got `None`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (medium) `rx07-no-strength/clean` **Calbo D** timing: got `not_specified`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (medium) `rx07-no-strength/clean` **Calbo D** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/clean` **Ecosprin** dose: got `None`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/clean` **Ecosprin** timing: got `not_specified`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/clean` **Ecosprin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx07-no-strength/clean` **Osartil** dose: got `None`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx07-no-strength/clean` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx07-no-strength/photo` **Calbo D** dose: got `None`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (medium) `rx07-no-strength/photo` **Calbo D** timing: got `not_specified`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (medium) `rx07-no-strength/photo` **Calbo D** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Calbo D', 'dose': '0+1+0', 'timing': 'after_meal', 'days': 90}`
- WRONG (low) `rx07-no-strength/photo` **Ecosprin** dose: got `None`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/photo` **Ecosprin** timing: got `not_specified`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (medium) `rx07-no-strength/photo` **Ecosprin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Ecosprin', 'dose': '0+1+0', 'timing': 'after_meal', 'continue': True}`
- WRONG (low) `rx07-no-strength/photo` **Osartil** dose: got `None`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (medium) `rx07-no-strength/photo` **Osartil** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Osartil', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx08-syrup-child/clean` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- WRONG (medium) `rx08-syrup-child/clean` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/clean` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/clean`: `2. Syp. Ace Plus` (name confidence high)
- WRONG (low) `rx08-syrup-child/photo` **Napa** dose: got `None`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- WRONG (medium) `rx08-syrup-child/photo` **Napa** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Napa', 'strength': '120 mg/5 ml', 'dose': '1+1+1', 'days': 3}`
- MISSING `rx08-syrup-child/photo` **Orsaline-N**: not found
- EXTRA `rx08-syrup-child/photo`: `2.Syp.Ace Plus` (name confidence high)
- WRONG (low) `rx09-four-times/clean` **Zimax** dose: got `None`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (low) `rx09-four-times/clean` **Zimax** timing: got `not_specified`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx09-four-times/clean` **Zimax** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (low) `rx09-four-times/photo` **Zimax** dose: got `None`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx09-four-times/photo` **Zimax** timing: got `not_specified`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (medium) `rx09-four-times/photo` **Zimax** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Zimax', 'strength': '500 mg', 'dose': '1+0+0', 'timing': 'empty_stomach', 'days': 3}`
- WRONG (low) `rx10-mixed/clean` **Cef-3** strength: got `3200mg`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/clean` **Cef-3** dose: got `None`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/clean` **Cef-3** timing: got `not_specified`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/clean` **Cef-3** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/clean` **Atova** dose: got `None`, expected `{'brand': 'Atova', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx10-mixed/clean` **Angilock** dose: got `None`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/clean` **Angilock** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (low) `rx10-mixed/clean` **Camlodin** dose: got `None`, expected `{'brand': 'Camlodin', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/clean` **Camlodin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Camlodin', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (low) `rx10-mixed/photo` **Cef-3** strength: got `3200mg`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/photo` **Cef-3** dose: got `None`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/photo` **Cef-3** timing: got `not_specified`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (medium) `rx10-mixed/photo` **Cef-3** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Cef-3', 'strength': '200 mg', 'dose': '1+0+1', 'timing': 'after_meal', 'days': 7}`
- WRONG (low) `rx10-mixed/photo` **Atova** dose: got `None`, expected `{'brand': 'Atova', 'strength': '10 mg', 'dose': '0+0+1', 'timing': 'not_specified', 'continue': True}`
- WRONG (low) `rx10-mixed/photo` **Angilock** dose: got `None`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/photo` **Angilock** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Angilock', 'strength': '50 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (low) `rx10-mixed/photo` **Camlodin** dose: got `None`, expected `{'brand': 'Camlodin', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
- WRONG (medium) `rx10-mixed/photo` **Camlodin** duration: got `days=None continue_indefinitely=False`, expected `{'brand': 'Camlodin', 'strength': '5 mg', 'dose': '1+0+0', 'timing': 'not_specified', 'days': 60}`
