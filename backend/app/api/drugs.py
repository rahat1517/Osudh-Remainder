from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request, status

from app.api.errors import api_error
from app.drugs.matcher import DrugMatcher
from app.drugs.models import Drug, DrugCandidate, MatchRequest, MatchResult

router = APIRouter(prefix="/drugs", tags=["drugs"])


def get_matcher(request: Request) -> DrugMatcher:
    return request.app.state.drug_matcher


MatcherDep = Annotated[DrugMatcher, Depends(get_matcher)]


@router.get("/search")
def search_drugs(
    matcher: MatcherDep,
    q: Annotated[str, Query(min_length=1, max_length=100, description="Brand or generic name")],
    limit: Annotated[int, Query(ge=1, le=50)] = 10,
) -> list[DrugCandidate]:
    """Autocomplete while typing. Tolerates misspellings."""
    return matcher.search(q, limit=limit)


@router.post("/match")
def match_drug(matcher: MatcherDep, body: MatchRequest) -> MatchResult:
    """Closest catalogue drug for one line read from a prescription, with a confidence level."""
    return matcher.match(body.text, limit=body.limit)


@router.get("/{drug_id}")
def get_drug(matcher: MatcherDep, drug_id: int) -> Drug:
    drug = matcher.get(drug_id)
    if drug is None:
        raise api_error(status.HTTP_404_NOT_FOUND, "drug_not_found", "No drug with this id")
    return drug
