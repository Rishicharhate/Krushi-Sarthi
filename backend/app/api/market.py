"""Mandi (APMC) market prices from Agmarknet via data.gov.in — see
app/connectors/agmarknet.py for the API-key situation.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.connectors import agmarknet
from app.db.database import get_db
from app.db.models import Farm, User
from app.schemas import MarketPriceOut

router = APIRouter(prefix="/market", tags=["market"])


@router.get("/prices", response_model=list[MarketPriceOut])
async def market_prices(
    commodity: str | None = None,
    state: str | None = None,
    district: str | None = None,
    farm_id: str | None = None,
    limit: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[MarketPriceOut]:
    """Latest reported mandi prices. With no `commodity` given, defaults to
    the crop on the caller's farm, so the screen shows something relevant
    without the farmer having to type their own crop in first."""
    if commodity is None:
        query = db.query(Farm).filter(Farm.user_id == user.id)
        farm = query.filter(Farm.id == farm_id).first() if farm_id else \
            query.filter(Farm.is_active.is_(True)).first()
        if farm is not None:
            commodity = farm.crop

    try:
        records = await agmarknet.get_mandi_prices(
            db, commodity=commodity, state=state, district=district, limit=limit
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"Agmarknet (data.gov.in) unavailable: {exc}",
        ) from exc

    return [MarketPriceOut(**r) for r in records]
