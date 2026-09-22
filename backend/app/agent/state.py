"""LangGraph state for the farm advisory agent (Phase 4,
docs/IMPLEMENTATION_PLAN.md §3). Defined once, up front — LangGraph's
checkpointer persists this shape, and changing it after checkpoints exist is
painful (the plan's own warning, §3.1).

All 5 specialists from the plan's §3.2 diagram are wired up: weather, soil,
disease, NDVI and market. (NDVI and market were added once it turned out
Sentinel-2 and Agmarknet are both reachable without the account signups
originally assumed — see app/connectors/sentinel.py's docstring.)
"""
import operator
from typing import Annotated, TypedDict


class Finding(TypedDict):
    domain: str  # 'weather' | 'soil' | 'disease' | 'irrigation' | 'ndvi' | 'market'
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
    ndvi: dict | None
    market: list | None

    # Parallel-safe accumulator — all five specialist nodes fan out and each
    # appends its own findings without clobbering the others (plan §3.1).
    findings: Annotated[list[Finding], operator.add]

    synthesis: str
    answer: str
    needs_human: bool
    safety_note: str | None
