"""Finds the closest catalogue drug for text read from a prescription.

Principle: saying "not sure" is far safer than a wrong answer marked certain. HIGH confidence is
given only when the name matches almost exactly, no other brand is close, and the strength (if
given) matches.
"""

from collections import defaultdict

from rapidfuzz import fuzz, process

from app.drugs.alternatives import cheaper_alternatives
from app.drugs.models import AlternativesResult, Confidence, Drug, DrugCandidate, MatchResult
from app.drugs.normalize import ParsedName, normalize_brand, parse, strength_numbers

HIGH_SCORE = 90.0
MEDIUM_SCORE = 70.0
# Minimum score gap between the best and second-best brand required for HIGH
HIGH_MARGIN = 8.0
STRENGTH_MISMATCH_PENALTY = 15.0


# Candidates shortlisted by the fast C scorer before the detailed scoring
PREFILTER = 50


def _name_score(query: str, choice: str, **_: object) -> float:
    """Exact similarity (ratio) dominates, so "napa" ranks "Napa" above "Napa Extend".
    WRatio contributes partial and reordered matches."""
    return 0.6 * fuzz.ratio(query, choice) + 0.4 * fuzz.WRatio(query, choice)


class DrugMatcher:
    def __init__(self, drugs: list[Drug]):
        self._drugs = drugs
        self._by_id = {d.id: d for d in drugs}
        self._by_brand: dict[str, list[Drug]] = defaultdict(list)
        for d in drugs:
            self._by_brand[normalize_brand(d.brand)].append(d)
        self._brand_keys = list(self._by_brand)
        # Brands with a digit in the name, such as "Cef-3"
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
    # One prescription line → closest drug
    # ------------------------------------------------------------------
    def cheaper_alternatives(self, drug_id: int, limit: int = 5) -> AlternativesResult | None:
        drug = self._by_id.get(drug_id)
        return None if drug is None else cheaper_alternatives(drug, self._drugs, limit)

    def match(self, text: str, limit: int = 5) -> MatchResult:
        parsed = parse(text)
        if not parsed.name:
            return MatchResult(query=text, confidence=Confidence.LOW, best=None, candidates=[])

        results = [self._match_parsed(text, parsed, limit)]
        if self._has_numeric_brands and parsed.strengths:
            # The first number may be part of the name: "Cef-3 200" → name "cef 3", strength 200
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
            # Name matches but this strength is not in the catalogue: the user must check it
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
    # Autocomplete: search brand or generic names while the user types
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

        # 1. Prefix matches on brand or generic name (the natural case while typing)
        for key in self._brand_keys:
            if key.startswith(q):
                add(self._by_brand[key], 100.0 - 0.1 * (len(key) - len(q)))  # shorter names first
        for key in self._generic_keys:
            if key.startswith(q):
                add(self._by_generic[key], 95.0 - 0.1 * (len(key) - len(q)))

        # 2. Misspellings: nearest brands and generics
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
        """Nearest brands in two stages: fast shortlist, then detailed scoring."""
        shortlist = process.extract(name, self._brand_keys, scorer=fuzz.WRatio, limit=PREFILTER)
        rescored = [(key, _name_score(name, key), idx) for key, _, idx in shortlist]
        rescored.sort(key=lambda hit: hit[1], reverse=True)
        return rescored[:limit]
