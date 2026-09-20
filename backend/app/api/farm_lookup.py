"""Shared helper: every geospatial endpoint needs a (lat, lon) pair, either
resolved from a farm_id the caller owns or passed directly."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models import Farm, User


def resolve_coordinates(
    db: Session,
    user: User,
    farm_id: str | None,
    lat: float | None,
    lon: float | None,
) -> tuple[float, float]:
    if lat is not None and lon is not None:
        return lat, lon

    if farm_id is not None:
        farm = db.query(Farm).filter(Farm.id == farm_id, Farm.user_id == user.id).first()
    else:
        farm = db.query(Farm).filter(Farm.user_id == user.id, Farm.is_active.is_(True)).first()

    if farm is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "No farm location available — pass farm_id/lat/lon, or set latitude "
            "and longitude on the active farm.",
        )
    if farm.latitude is None or farm.longitude is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Farm '{farm.name}' has no coordinates set. Edit the farm and add a location.",
        )
    return farm.latitude, farm.longitude
