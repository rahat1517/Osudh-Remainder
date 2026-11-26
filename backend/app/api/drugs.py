from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.drugs.matcher import DrugMatcher
from app.drugs.models import Drug, DrugCandidate, MatchRequest, MatchResult

router = APIRouter(prefix="/drugs", tags=["drugs"])


def get_matcher(request: Request) -> DrugMatcher:
    return request.app.state.drug_matcher


MatcherDep = Annotated[DrugMatcher, Depends(get_matcher)]


@router.get("/search")
def search_drugs(
    matcher: MatcherDep,
    q: Annotated[str, Query(min_length=1, max_length=100, description="brand বা generic নাম")],
    limit: Annotated[int, Query(ge=1, le=50)] = 10,
) -> list[DrugCandidate]:
    """টাইপ করার সময় autocomplete-এর জন্য। ভুল বানানেও কাজ করে।"""
    return matcher.search(q, limit=limit)


@router.post("/match")
def match_drug(matcher: MatcherDep, body: MatchRequest) -> MatchResult:
    """প্রেসক্রিপশন থেকে পড়া একটা লাইনের সবচেয়ে কাছের ওষুধ, confidence-সহ।"""
    return matcher.match(body.text, limit=body.limit)


@router.get("/{drug_id}")
def get_drug(matcher: MatcherDep, drug_id: int) -> Drug:
    drug = matcher.get(drug_id)
    if drug is None:
        raise HTTPException(status_code=404, detail="ওষুধ পাওয়া যায়নি")
    return drug
