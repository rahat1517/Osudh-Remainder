"""প্রেসক্রিপশনের লেখা থেকে সবচেয়ে কাছের ওষুধ খুঁজে বের করা।

মূল নীতি: ভুল কিন্তু "নিশ্চিত" উত্তরের চেয়ে "নিশ্চিত নই" বলা অনেক নিরাপদ।
তাই confidence HIGH দেওয়া হয় শুধু যখন নাম প্রায় হুবহু মেলে, অন্য কাছাকাছি নাম নেই,
আর শক্তি (থাকলে) মেলে।
"""

from collections import defaultdict

from rapidfuzz import fuzz, process

from app.drugs.models import Confidence, Drug, DrugCandidate, MatchResult
from app.drugs.normalize import ParsedName, normalize_brand, parse, strength_numbers

HIGH_SCORE = 90.0
MEDIUM_SCORE = 70.0
# HIGH-এর জন্য সবচেয়ে ভালো আর দ্বিতীয় brand-এর মধ্যে ন্যূনতম পার্থক্য
HIGH_MARGIN = 8.0
STRENGTH_MISMATCH_PENALTY = 15.0


# প্রথম ধাপে দ্রুত (C) scorer দিয়ে এতগুলো প্রার্থী বাছাই, তারপর শুধু এদের বিস্তারিত হিসাব
PREFILTER = 50


def _name_score(query: str, choice: str, **_: object) -> float:
    """হুবহু মিল (ratio) বেশি গুরুত্ব পায়, যাতে "napa" প্রশ্নে "Napa Extend"-এর চেয়ে "Napa" এগিয়ে থাকে।
    WRatio আংশিক বা ক্রম-বদলানো মিল ধরে।"""
    return 0.6 * fuzz.ratio(query, choice) + 0.4 * fuzz.WRatio(query, choice)


class DrugMatcher:
    def __init__(self, drugs: list[Drug]):
        self._drugs = drugs
        self._by_id = {d.id: d for d in drugs}
        self._by_brand: dict[str, list[Drug]] = defaultdict(list)
        for d in drugs:
            self._by_brand[normalize_brand(d.brand)].append(d)
        self._brand_keys = list(self._by_brand)
        # "Cef-3"-এর মতো যেসব brand-এর নামেই সংখ্যা আছে
        self._has_numeric_brands = any(ch.isdigit() for key in self._brand_keys for ch in key)
        self._by_generic: dict[str, list[Drug]] = defaultdict(list)
        for d in drugs:
            self._by_generic[d.generic.lower()].append(d)
        self._generic_keys = list(self._by_generic)

    def __len__(self) -> int:
        return len(self._drugs)

    def get(self, drug_id: int) -> Drug | None:
        return self._by_id.get(drug_id)

    # ------------------------------------------------------------------
    # প্রেসক্রিপশনের একটা লাইন → সবচেয়ে কাছের ওষুধ
    # ------------------------------------------------------------------
    def match(self, text: str, limit: int = 5) -> MatchResult:
        parsed = parse(text)
        if not parsed.name:
            return MatchResult(query=text, confidence=Confidence.LOW, best=None, candidates=[])

        results = [self._match_parsed(text, parsed, limit)]
        if self._has_numeric_brands and parsed.strengths:
            # প্রথম সংখ্যাটা নামের অংশও হতে পারে: "Cef-3 200" → নাম "cef 3", শক্তি 200
            alt = ParsedName(f"{parsed.name} {parsed.strengths[0]}", parsed.strengths[1:])
            results.append(self._match_parsed(text, alt, limit))
        return max(results, key=lambda r: r.best.score if r.best else -1.0)

    def _match_parsed(self, text: str, parsed: ParsedName, limit: int) -> MatchResult:
        brand_hits = self._top_brands(parsed.name, max(limit, 5))

        candidates: list[DrugCandidate] = []
        for brand_key, score, _ in brand_hits:
            for drug in self._by_brand[brand_key]:
                candidates.append(self._score_variant(drug, score, parsed.strengths))
        candidates.sort(key=lambda c: (c.score, c.strength_matched is True), reverse=True)
        candidates = candidates[:limit]

        best = candidates[0] if candidates else None
        confidence = self._confidence(best, brand_hits)
        return MatchResult(query=text, confidence=confidence, best=best, candidates=candidates)

    @staticmethod
    def _score_variant(
        drug: Drug, name_score: float, query_strengths: tuple[str, ...]
    ) -> DrugCandidate:
        if not query_strengths:
            return DrugCandidate(drug=drug, score=round(name_score, 1), strength_matched=None)
        drug_strengths = strength_numbers(drug.strength)
        matched = bool(drug_strengths) and set(query_strengths).issubset(drug_strengths)
        score = name_score if matched else name_score - STRENGTH_MISMATCH_PENALTY
        return DrugCandidate(drug=drug, score=round(max(score, 0.0), 1), strength_matched=matched)

    @staticmethod
    def _confidence(
        best: DrugCandidate | None, brand_hits: list[tuple[str, float, int]]
    ) -> Confidence:
        if best is None:
            return Confidence.LOW
        if best.strength_matched is False:
            # নাম মিলেছে কিন্তু এই শক্তির ওষুধ তালিকায় নেই: ব্যবহারকারীকে দেখাতেই হবে
            return (
                Confidence.MEDIUM
                if best.score >= MEDIUM_SCORE - STRENGTH_MISMATCH_PENALTY
                else Confidence.LOW
            )
        top = brand_hits[0][1]
        runner_up = brand_hits[1][1] if len(brand_hits) > 1 else 0.0
        if best.score >= HIGH_SCORE and top - runner_up >= HIGH_MARGIN:
            return Confidence.HIGH
        if best.score >= MEDIUM_SCORE:
            return Confidence.MEDIUM
        return Confidence.LOW

    # ------------------------------------------------------------------
    # Autocomplete: ব্যবহারকারী টাইপ করার সময় brand বা generic নামে খোঁজা
    # ------------------------------------------------------------------
    def search(self, query: str, limit: int = 10) -> list[DrugCandidate]:
        parsed = parse(query)
        q = parsed.name
        if not q:
            return []

        scores: dict[int, float] = {}

        def add(drugs: list[Drug], score: float) -> None:
            for drug in drugs:
                if score > scores.get(drug.id, -1.0):
                    scores[drug.id] = score

        # ১. brand বা generic নামের শুরুতে মিল (টাইপ করার সময় সবচেয়ে স্বাভাবিক)
        for key in self._brand_keys:
            if key.startswith(q):
                add(self._by_brand[key], 100.0 - 0.1 * (len(key) - len(q)))  # ছোট নাম আগে
        for key in self._generic_keys:
            if key.startswith(q):
                add(self._by_generic[key], 95.0 - 0.1 * (len(key) - len(q)))

        # ২. ভুল বানান: কাছাকাছি brand ও generic
        for key, score, _ in self._top_brands(q, limit):
            add(self._by_brand[key], score)
        for key, score, _ in process.extract(
            q, self._generic_keys, scorer=fuzz.partial_ratio, limit=limit
        ):
            add(self._by_generic[key], 0.9 * score)

        ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
        results = [
            self._score_variant(self._by_id[drug_id], s, parsed.strengths)
            for drug_id, s in ranked
            if s >= MEDIUM_SCORE - 10
        ][:limit]
        results.sort(key=lambda c: c.score, reverse=True)
        return results

    def _top_brands(self, name: str, limit: int) -> list[tuple[str, float, int]]:
        """দুই ধাপে সবচেয়ে কাছের brand: দ্রুত বাছাই, তারপর বিস্তারিত হিসাব।"""
        shortlist = process.extract(name, self._brand_keys, scorer=fuzz.WRatio, limit=PREFILTER)
        rescored = [(key, _name_score(name, key), idx) for key, _, idx in shortlist]
        rescored.sort(key=lambda hit: hit[1], reverse=True)
        return rescored[:limit]
