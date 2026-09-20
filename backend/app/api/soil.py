from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.agronomy.soil_status import (
    classify_moisture,
    classify_ph,
    estimate_nitrogen_index,
    estimate_phosphorus,
    estimate_potassium,
    overall_soil_status,
)
from app.api.deps import get_current_user
from app.api.farm_lookup import resolve_coordinates
from app.connectors import open_meteo, soilgrids
from app.db.database import get_db
from app.db.models import User
from app.schemas import SoilDataOut, SoilHistoryPointOut

router = APIRouter(prefix="/soil", tags=["soil"])


@router.get("/current", response_model=SoilDataOut)
async def current_soil(
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SoilDataOut:
    coords = resolve_coordinates(db, user, farm_id, lat, lon)

    try:
        profile = await soilgrids.get_soil_profile(db, coords[0], coords[1])
    except Exception:  # noqa: BLE001 — soil baseline is non-critical, degrade gracefully
        profile = None
    try:
        moisture = await open_meteo.get_soil_moisture(db, coords[0], coords[1])
    except Exception:  # noqa: BLE001
        moisture = None

    if profile is None and moisture is None:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            "Soil data providers unavailable — check network access to "
            "rest.isric.org and api.open-meteo.com.",
        )

    ph = profile["ph"] if profile and profile.get("ph") is not None else 6.5
    moisture_pct = moisture["moisture_pct"] if moisture else 45.0
    soil_temp = (
        moisture["soil_temperature"]
        if moisture and moisture.get("soil_temperature") is not None
        else 25.0
    )
    nitrogen = estimate_nitrogen_index(profile.get("nitrogen_mg_kg") if profile else None)
    phosphorus = estimate_phosphorus(
        profile.get("soc_pct") if profile else None, profile.get("clay_pct") if profile else None
    )
    potassium = estimate_potassium(
        profile.get("clay_pct") if profile else None, profile.get("sand_pct") if profile else None
    )

    moisture_status = classify_moisture(moisture_pct)
    ph_status = classify_ph(ph)

    return SoilDataOut(
        moisture=moisture_pct,
        temperature=soil_temp,
        ph=ph,
        nitrogen=nitrogen,
        phosphorus=phosphorus,
        potassium=potassium,
        moisture_status=moisture_status,
        ph_status=ph_status,
        overall_status=overall_soil_status(moisture_status, ph_status),
        updated_at=datetime.now(timezone.utc),
    )


@router.get("/history", response_model=list[SoilHistoryPointOut])
async def soil_history(
    param: str = "Moisture",
    days: int = 7,
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[SoilHistoryPointOut]:
    """Only 'Moisture' and 'Temperature' are backed by a real time series today
    (via Open-Meteo's soil variables). 'pH' has no daily-changing free source —
    SoilGrids is a static baseline — so it is intentionally NOT exposed as a
    history series here; the Flutter side falls back to demo data for it until
    a real soil-test time series exists (see docs/IMPLEMENTATION_PLAN.md)."""
    coords = resolve_coordinates(db, user, farm_id, lat, lon)
    param_lower = param.lower()
    if param_lower not in ("moisture", "temperature"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"No real daily history for soil parameter '{param}' yet.",
        )
    try:
        if param_lower == "moisture":
            points = await open_meteo.get_soil_moisture_history(db, coords[0], coords[1], days)
        else:
            points = await open_meteo.get_weather_history(db, coords[0], coords[1], "temperature", days)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Soil provider error: {exc}") from exc
    return [SoilHistoryPointOut(**p) for p in points]
