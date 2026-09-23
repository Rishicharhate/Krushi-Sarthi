"""Crop health / NDVI from real Sentinel-2 imagery — see
app/connectors/sentinel.py (no account, no API key, cloud-masked).

When the field has had no cloud-free satellite pass in the lookback window,
these endpoints return 404 with a plain explanation rather than an NDVI
number measured through cloud. During an Indian monsoon that can be the
honest answer for weeks at a time.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.farm_lookup import resolve_coordinates
from app.connectors import sentinel
from app.db.database import get_db
from app.db.models import Farm, User
from app.schemas import CropHealthOut, NdviHistoryPointOut

router = APIRouter(prefix="/crop", tags=["crop"])

_FETCHING = (
    "Fetching satellite imagery for this field. The first time can take a "
    "minute or two; tap Try Again shortly."
)

_NO_CLEAR_VIEW = (
    "No cloud-free satellite view of this field in the last {days} days. "
    "Sentinel-2 can only see the crop when there are no clouds overhead, which "
    "is common during monsoon — this is a real gap in the data, not an error."
)


def _crop_name(db: Session, user: User, farm_id: str | None) -> str:
    query = db.query(Farm).filter(Farm.user_id == user.id)
    farm = query.filter(Farm.id == farm_id).first() if farm_id else \
        query.filter(Farm.is_active.is_(True)).first()
    return farm.crop if farm else "Crop"


@router.get("/health", response_model=CropHealthOut)
async def crop_health(
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    days: int = 90,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CropHealthOut:
    coords = resolve_coordinates(db, user, farm_id, lat, lon)
    try:
        latest = await sentinel.get_latest_ndvi(db, coords[0], coords[1], days=days)
    except sentinel.NdviPending as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, _FETCHING) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Sentinel-2 unavailable: {exc}") from exc

    if latest is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, _NO_CLEAR_VIEW.format(days=days))

    return CropHealthOut(
        ndvi=latest["ndvi"],
        health_status=latest["health_status"],
        crop=_crop_name(db, user, farm_id),
        date=latest["date"],
        previous_ndvi=latest.get("previous_ndvi"),
        ndvi_change=latest.get("ndvi_change"),
    )


@router.get("/ndvi/history", response_model=list[NdviHistoryPointOut])
async def ndvi_history(
    farm_id: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    days: int = 90,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[NdviHistoryPointOut]:
    coords = resolve_coordinates(db, user, farm_id, lat, lon)
    try:
        series = await sentinel.get_ndvi_series(db, coords[0], coords[1], days=days)
    except sentinel.NdviPending as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, _FETCHING) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Sentinel-2 unavailable: {exc}") from exc

    # Oldest first, so the trend chart reads left to right.
    return [
        NdviHistoryPointOut(date=r["date"], ndvi=r["ndvi"], health_status=r["health_status"])
        for r in sorted(series, key=lambda r: r["date"])
    ]
