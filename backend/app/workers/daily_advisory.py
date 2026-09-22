"""Phase 5's daily automation worker (docs/IMPLEMENTATION_PLAN.md §5): the
piece that makes this "automated for farmers" instead of "real data on
request." Scheduled to run once per morning (05:30 IST, see app/main.py)
across every farm with coordinates set. Reuses the same specialist tools the
interactive agent uses (app/agent/tools.py) rather than duplicating that
logic, and only writes a notification when something actually crosses a
threshold worth telling a farmer about — most days, nothing fires, on
purpose (see the prompt below: the model is explicitly told an empty list is
the normal, expected answer).

NDVI and market-price findings are not included here for the same reason
they're not in the Phase 4 agent — those connectors don't exist yet.
"""
import json
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.agent import tools
from app.agent.llm import get_llm
from app.db.database import SessionLocal
from app.db.models import Farm, Notification

_VALID_CATEGORIES = {"Soil Alerts", "Environmental Alerts", "Crop Health Alerts", "Disease Alerts"}

_DAILY_PROMPT = """You are KrushiSarthi, reviewing one farm's current conditions each morning on the
farmer's behalf, without them asking. The farmer grows {crop}.

Findings for today:
{findings}

Decide if there is anything genuinely worth telling this farmer today. Most days nothing urgent has
changed — in that case return an empty list; do not invent a reason to notify just to say something.
Only include an advisory when a finding crosses a real, specific threshold (a meaningful irrigation
deficit, low soil moisture, a recent disease detection, extreme weather). Do not invent numbers that
are not present in the findings above.

Return ONLY valid JSON in this exact shape, nothing else, no markdown fences:
{{"advisories": [{{"title": "short title, under 8 words", "message": "1-2 sentences, plain language, cite the specific number", "category": "Soil Alerts" | "Environmental Alerts" | "Crop Health Alerts" | "Disease Alerts", "priority": "high" | "medium" | "low"}}]}}
At most 3 items, ranked most important first."""


async def _gather_findings(db: Session, farm: Farm) -> list[dict]:
    findings: list[dict] = []

    try:
        weather = await tools.fetch_weather_and_irrigation(db, farm.latitude, farm.longitude, farm.crop)
        irrigation = weather["irrigation"]
        findings.append({
            "domain": "irrigation",
            "summary": (
                f"Over the next {irrigation['days']} days: crop water use "
                f"~{irrigation['crop_water_use_mm']}mm, effective rainfall "
                f"~{irrigation['effective_rainfall_mm']}mm -> irrigation need "
                f"~{irrigation['irrigation_need_mm']}mm."
            ),
        })
    except Exception:  # noqa: BLE001 — one failed source shouldn't block the rest
        pass

    try:
        soil = await tools.fetch_soil(db, farm.latitude, farm.longitude)
        if soil.get("moisture_pct") is not None:
            findings.append({
                "domain": "soil",
                "summary": f"Soil moisture {soil['moisture_pct']:.0f}% ({soil['moisture_status']}).",
            })
    except Exception:  # noqa: BLE001
        pass

    try:
        scans = tools.fetch_recent_disease_scans(db, farm.user_id, days=2)
        if scans:
            latest = scans[0]
            findings.append({
                "domain": "disease",
                "summary": f"Leaf scan today: {latest['disease']} at {latest['confidence']:.0f}% confidence.",
            })
    except Exception:  # noqa: BLE001
        pass

    return findings


def _parse_advisories(raw: str) -> list[dict]:
    text = raw.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return []
    items = data.get("advisories", [])
    return items[:3] if isinstance(items, list) else []


async def run_daily_advisory_for_farm(db: Session, farm: Farm) -> int:
    """Gathers findings, asks the LLM whether anything is worth flagging, and
    writes 0-3 Notification rows. Returns how many were written."""
    if farm.latitude is None or farm.longitude is None:
        return 0

    findings = await _gather_findings(db, farm)
    if not findings:
        return 0

    findings_text = "\n".join(f"- [{f['domain']}] {f['summary']}" for f in findings)
    llm = get_llm()
    response = await llm.ainvoke(_DAILY_PROMPT.format(crop=farm.crop, findings=findings_text))
    advisories = _parse_advisories(response.content)

    now = datetime.now(timezone.utc)
    for item in advisories:
        category = item.get("category")
        db.add(Notification(
            id=str(uuid.uuid4()),
            user_id=farm.user_id,
            title=str(item.get("title", "Farm Advisory"))[:160],
            message=str(item.get("message", "")),
            category=category if category in _VALID_CATEGORIES else "Environmental Alerts",
            icon=None,
            is_read=False,
            timestamp=now,
        ))
    if advisories:
        db.commit()
    return len(advisories)


async def run_daily_advisory_for_all_farms() -> dict:
    """The real cron entry point — see app/main.py's scheduler wiring
    (05:30 IST). One DB session for the whole run; one farm's failure
    doesn't block the others."""
    db = SessionLocal()
    farms_checked = notifications_written = 0
    try:
        farms = (
            db.query(Farm)
            .filter(Farm.latitude.isnot(None), Farm.longitude.isnot(None))
            .all()
        )
        for farm in farms:
            farms_checked += 1
            try:
                notifications_written += await run_daily_advisory_for_farm(db, farm)
            except Exception:  # noqa: BLE001 — keep going for the rest of the farms
                continue
    finally:
        db.close()
    return {"farms_checked": farms_checked, "notifications_written": notifications_written}
