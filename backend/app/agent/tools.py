"""Thin, typed wrappers the specialist nodes call. Every external/DB read the
agent can see goes through here, one function per data source — matching
docs/IMPLEMENTATION_PLAN.md §3.3's tool table, scoped to the 3 domains with
real data behind them right now (weather, soil, disease). The agent never
calls a connector or the DB directly from a node.
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.agronomy import soil_status, water_balance
from app.connectors import open_meteo, soilgrids
from app.db.models import DiseaseScan


async def fetch_weather_and_irrigation(
    db: Session, lat: float, lon: float, crop: str, days: int = 3
) -> dict:
    current = await open_meteo.get_current_weather(db, lat, lon)
    et0 = await open_meteo.get_et0(db, lat, lon, days)
    irrigation = water_balance.irrigation_need_mm(et0["et0_mm"], et0["rainfall_mm"], crop)
    return {"current": current, "et0": et0, "irrigation": irrigation}


async def fetch_soil(db: Session, lat: float, lon: float) -> dict:
    profile = None
    moisture = None
    try:
        profile = await soilgrids.get_soil_profile(db, lat, lon)
    except Exception:  # noqa: BLE001 — degrade gracefully, same as app/api/soil.py
        pass
    try:
        moisture = await open_meteo.get_soil_moisture(db, lat, lon)
    except Exception:  # noqa: BLE001
        pass

    ph = profile["ph"] if profile and profile.get("ph") is not None else None
    moisture_pct = moisture["moisture_pct"] if moisture else None
    return {
        "ph": ph,
        "ph_status": soil_status.classify_ph(ph) if ph is not None else None,
        "moisture_pct": moisture_pct,
        "moisture_status": soil_status.classify_moisture(moisture_pct) if moisture_pct is not None else None,
    }


def fetch_recent_disease_scans(db: Session, user_id: str, days: int = 7, limit: int = 3) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    scans = (
        db.query(DiseaseScan)
        .filter(DiseaseScan.user_id == user_id, DiseaseScan.scanned_at >= cutoff)
        .order_by(DiseaseScan.scanned_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "disease": s.disease,
            "confidence": s.confidence,
            "crop": s.crop,
            "scanned_at": s.scanned_at.isoformat(),
        }
        for s in scans
    ]
