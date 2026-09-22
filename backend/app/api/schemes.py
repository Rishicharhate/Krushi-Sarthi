"""Government schemes — Phase 5's "Scheme RAG" (docs/IMPLEMENTATION_PLAN.md
§5). Real corpus + semantic search — see app/rag/ and
app/data/SCHEMES_SOURCES.md for what's in it and where it came from.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import get_current_user
from app.db.models import User
from app.rag.search import get_scheme, list_schemes, search_schemes
from app.schemas import GovernmentSchemeOut

router = APIRouter(prefix="/schemes", tags=["schemes"])


def _to_out(scheme: dict) -> GovernmentSchemeOut:
    return GovernmentSchemeOut(**scheme)


@router.get("", response_model=list[GovernmentSchemeOut])
async def get_schemes(user: User = Depends(get_current_user)) -> list[GovernmentSchemeOut]:
    return [_to_out(s) for s in list_schemes()]


@router.get("/search", response_model=list[GovernmentSchemeOut])
async def search(
    q: str = Query(..., min_length=1),
    top_k: int = Query(5, ge=1, le=20),
    user: User = Depends(get_current_user),
) -> list[GovernmentSchemeOut]:
    """Semantic search over the scheme corpus — matches on meaning, not just
    keyword overlap (e.g. "money if rain ruins my crop" should surface PMFBY
    crop insurance with no shared words). Registered before /{scheme_id} so
    FastAPI doesn't treat "search" as a scheme id."""
    ranked = search_schemes(q, top_k=top_k)
    return [_to_out(s) for s, _score in ranked]


@router.get("/{scheme_id}", response_model=GovernmentSchemeOut)
async def get_scheme_detail(
    scheme_id: str, user: User = Depends(get_current_user)
) -> GovernmentSchemeOut:
    scheme = get_scheme(scheme_id)
    if scheme is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Scheme not found.")
    return _to_out(scheme)
