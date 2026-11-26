import csv

from app.drugs.models import Confidence


def _load_cases(data_dir):
    with (data_dir / "misspellings.csv").open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def test_misspelling_accuracy_at_least_90_percent(matcher, data_dir):
    """Phase 1-এর শেষের শর্ত: ভুল বানানের test set-এ ≥ ৯০% সঠিক মিল।"""
    cases = _load_cases(data_dir)
    assert len(cases) >= 50
    failures = []
    for case in cases:
        result = matcher.match(case["query"])
        best = result.best
        ok = best is not None and best.drug.brand == case["expected_brand"]
        if ok and case["expected_strength"]:
            ok = best.drug.strength == case["expected_strength"]
        if not ok:
            got = f"{best.drug.brand} {best.drug.strength}" if best else None
            failures.append(f"{case['query']!r} → {got} (প্রত্যাশিত {case['expected_brand']})")
    accuracy = 1 - len(failures) / len(cases)
    assert accuracy >= 0.90, f"নির্ভুলতা {accuracy:.0%}\n" + "\n".join(failures)


def test_exact_name_and_strength_is_high_confidence(matcher):
    result = matcher.match("Seclo 20")
    assert result.confidence == Confidence.HIGH
    assert result.best.drug.strength == "20 mg"
    assert result.best.strength_matched is True


def test_prefers_exact_brand_over_longer_brand(matcher):
    # "Napa" লিখলে "Napa Extend" নয়, "Napa" আসা উচিত
    assert matcher.match("Napa 500").best.drug.brand == "Napa"


def test_strength_not_in_catalog_is_never_high(matcher):
    # Seclo 60 তালিকায় নেই: নাম মিললেও নিশ্চিত বলা যাবে না
    result = matcher.match("Seclo 60")
    assert result.best.drug.brand == "Seclo"
    assert result.best.strength_matched is False
    assert result.confidence != Confidence.HIGH


def test_unknown_drug_is_low_confidence(matcher):
    result = matcher.match("Xyzqwe 500")
    assert result.confidence == Confidence.LOW


def test_partial_ocr_is_not_high_confidence(matcher):
    # "Ma?x": OCR অর্ধেক পড়েছে। প্রস্তাব দেওয়া যায়, কিন্তু নিশ্চিত বলা যায় না
    result = matcher.match("Ma?x")
    assert result.confidence != Confidence.HIGH
    assert "Maxpro" in [c.drug.brand for c in result.candidates]


def test_typo_is_not_high_confidence_when_ambiguous(matcher):
    # "Sedil" আর "Seclo" কাছাকাছি; বড় ধরনের টাইপো হলে HIGH দেওয়া যাবে না
    result = matcher.match("Sel 5")
    assert result.confidence != Confidence.HIGH


def test_empty_text(matcher):
    result = matcher.match("Tab.")
    assert result.best is None
    assert result.confidence == Confidence.LOW


def test_search_by_brand_prefix(matcher):
    results = matcher.search("sec")
    assert results[0].drug.brand == "Seclo"


def test_search_by_generic(matcher):
    brands = {c.drug.brand for c in matcher.search("esomeprazole")}
    assert {"Maxpro", "Sergel", "Nexum", "Esonix"} <= brands


def test_search_with_typo(matcher):
    assert matcher.search("maxpo")[0].drug.brand == "Maxpro"


def test_brand_with_digit_in_name(matcher):
    # "Cef-3"-এর 3 নামের অংশ, শক্তি নয়
    for text in ("Cef-3 200", "Cef 3 400", "Cap. Cef-3 400mg"):
        result = matcher.match(text)
        assert result.best.drug.brand == "Cef-3", text
        assert result.best.strength_matched is True, text
    assert matcher.match("Cef-3 200").confidence == Confidence.HIGH


def test_ocr_digit_at_end_of_name(matcher):
    result = matcher.match("Maxpr0 40")
    assert result.best.drug.brand == "Maxpro"
    assert result.best.drug.strength == "40 mg"
