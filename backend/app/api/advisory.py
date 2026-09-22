"""Phase 4 — the LangGraph farm advisory agent. POST /api/advisory/ask takes
a free-text question and returns a sourced answer, backed by real
weather/soil/disease data (see app/agent/). Conversation state persists per
(user, farm) via a SQLite checkpointer — the daily-automation worker that
would actually use that persistence across turns is Phase 5, not this.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.agent.graph import get_graph
from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Farm, User
from app.schemas import AdvisoryAskIn, AdvisoryAskOut, AdvisorySourceOut

router = APIRouter(prefix="/advisory", tags=["advisory"])


@router.post("/ask", response_model=AdvisoryAskOut)
async def ask_advisory(
    payload: AdvisoryAskIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AdvisoryAskOut:
    farm = db.query(Farm).filter(Farm.id == payload.farm_id, Farm.user_id == user.id).first()
    if farm is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farm not found.")
    if farm.latitude is None or farm.longitude is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Farm '{farm.name}' has no coordinates set. Edit the farm and add a location.",
        )

    graph = get_graph()
    initial_state = {
        "farm": {
            "farm_id": farm.id,
            "crop": farm.crop,
            "latitude": farm.latitude,
            "longitude": farm.longitude,
            "soil_type": farm.soil_type,
        },
        "user_id": user.id,
        "question": payload.question,
        "findings": [],
    }
    config = {"configurable": {"thread_id": f"{user.id}:{farm.id}"}}
    try:
        result = await graph.ainvoke(initial_state, config=config)
    except RuntimeError as exc:
        # Agent not initialized, or get_llm()'s missing-GROQ_API_KEY message.
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(exc)) from exc
    except Exception as exc:  # noqa: BLE001 — surface the real cause to the caller
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Advisory agent error: {exc}") from exc

    return AdvisoryAskOut(
        answer=result["answer"],
        needs_human=result.get("needs_human", False),
        safety_note=result.get("safety_note"),
        sources=[AdvisorySourceOut(**f) for f in result.get("findings", [])],
    )
