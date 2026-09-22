"""Notifications — Phase 5. Real notifications are written by the daily
automation worker (app/workers/daily_advisory.py), either by the 05:30 IST
cron job (app/main.py) or the manual trigger below, which exists so this is
demonstrable on demand rather than only at 5:30 tomorrow morning.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Farm, Notification, User
from app.schemas import NotificationItemOut
from app.workers.daily_advisory import run_daily_advisory_for_farm

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _to_out(n: Notification) -> NotificationItemOut:
    return NotificationItemOut(
        id=n.id, title=n.title, message=n.message, category=n.category,
        timestamp=n.timestamp, is_read=n.is_read, icon=n.icon,
    )


def _list_for_user(db: Session, user_id: str) -> list[NotificationItemOut]:
    notifs = (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.timestamp.desc())
        .limit(50)
        .all()
    )
    return [_to_out(n) for n in notifs]


@router.get("", response_model=list[NotificationItemOut])
async def get_notifications(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[NotificationItemOut]:
    return _list_for_user(db, user.id)


@router.post("/run-daily", response_model=list[NotificationItemOut])
async def run_daily_now(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[NotificationItemOut]:
    """Manually runs the daily-advisory check for the CALLER's own farms
    right now instead of waiting for the scheduled 05:30 IST job — for
    demos/testing. The real automation is the cron job in app/main.py."""
    farms = (
        db.query(Farm)
        .filter(Farm.user_id == user.id, Farm.latitude.isnot(None), Farm.longitude.isnot(None))
        .all()
    )
    for farm in farms:
        await run_daily_advisory_for_farm(db, farm)
    return _list_for_user(db, user.id)
