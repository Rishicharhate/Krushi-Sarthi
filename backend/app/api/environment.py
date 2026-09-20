from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.agronomy.soil_status import classify_humidity, classify_temperature
from app.api.deps import get_current_user
from app.api.farm_lookup import resolve_coordinates
from app.connectors import open_meteo
from app.db.database import get_db
from app.db.models import User
from app.schemas import EnvironmentDataOut, EnvironmentHistoryPointOut

router = APIRouter(prefix="/environment", tags=["environment"])


@router.get("/current", response_model=EnvironmentDataOut)
async def current_environment(
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> EnvironmentDataOut:
    coords = resolve_coordinates(db, user, farm_id, lat, lon)
    try:
        raw = await open_meteo.get_current_weather(db, coords[0], coords[1])
    except Exception as exc:  # noqa: BLE001 — surface upstream failure, don't fabricate data
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Weather provider error: {exc}") from exc

    return EnvironmentDataOut(
        temperature=raw["temperature"],
        humidity=raw["humidity"],
        rainfall=raw["rainfall"],
        wind_speed=raw["wind_speed"],
        temperature_status=classify_temperature(raw["temperature"]),
        humidity_status=classify_humidity(raw["humidity"]),
        updated_at=raw["updated_at"],
    )


@router.get("/history", response_model=list[EnvironmentHistoryPointOut])
async def environment_history(
    param: str = "Temperature",
    days: int = 7,
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[EnvironmentHistoryPointOut]:
    coords = resolve_coordinates(db, user, farm_id, lat, lon)
    field = "humidity" if param.lower() == "humidity" else "temperature"
    try:
        points = await open_meteo.get_weather_history(db, coords[0], coords[1], field, days)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Weather provider error: {exc}") from exc
    return [EnvironmentHistoryPointOut(**p) for p in points]
