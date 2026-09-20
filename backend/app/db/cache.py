"""Thin TTL cache over the api_cache table. Keeps external connectors inside
their free-tier rate limits (SoilGrids: ~5 calls/min; Open-Meteo: 10k/day)."""
import json
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.db.models import ApiCache


def cache_get(db: Session, key: str, ttl_seconds: int) -> Any | None:
    row = db.query(ApiCache).filter(ApiCache.cache_key == key).first()
    if row is None:
        return None
    age = datetime.now(timezone.utc) - row.fetched_at.replace(tzinfo=timezone.utc)
    if age > timedelta(seconds=ttl_seconds):
        return None
    return json.loads(row.payload)


def cache_set(db: Session, key: str, value: Any) -> None:
    row = db.query(ApiCache).filter(ApiCache.cache_key == key).first()
    payload = json.dumps(value)
    if row is None:
        db.add(ApiCache(cache_key=key, payload=payload))
    else:
        row.payload = payload
        row.fetched_at = datetime.now(timezone.utc)
    db.commit()
