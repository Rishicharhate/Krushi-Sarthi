"""LangGraph state for the farm advisory agent (Phase 4,
docs/IMPLEMENTATION_PLAN.md §3). Defined once, up front — LangGraph's
checkpointer persists this shape, and changing it after checkpoints exist is
painful (the plan's own warning, §3.1).

Scope: 3 specialists with real data behind them today — weather, soil,
disease. NDVI and market-price specialists are deliberately not included;
those connectors don't exist yet (see docs/STATUS.md). Add them as new
TypedDict fields here plus new nodes in nodes.py/graph.py once they do —
nothing else needs to change.
"""
import operator
from typing import Annotated, TypedDict


class Finding(TypedDict):
    domain: str  # 'weather' | 'soil' | 'disease' | 'irrigation'
    summary: str  # short, human-readable, farmer-relevant fact
    source: str  # which tool/API produced it — provenance, not vibes


class FarmContext(TypedDict):
    farm_id: str
    crop: str
    latitude: float
    longitude: float
    soil_type: str | None


class FarmState(TypedDict):
    farm: FarmContext
    user_id: str
    question: str

    weather: dict | None
    soil: dict | None
    disease: dict | None
    irrigation: dict | None

    # Parallel-safe accumulator — weather/soil/disease nodes fan out and each
    # appends its own findings without clobbering the others (plan §3.1).
    findings: Annotated[list[Finding], operator.add]

    synthesis: str
    answer: str
    needs_human: bool
    safety_note: str | None
