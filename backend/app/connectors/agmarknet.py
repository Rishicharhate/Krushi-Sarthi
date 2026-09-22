"""Agmarknet daily mandi prices via data.gov.in — real APMC market prices
for agricultural commodities across India.

This is the one connector that needs an API key. data.gov.in publishes a
sample key in its own API documentation, which is what `settings.data_gov_api_key`
defaults to, so this works out of the box. Two caveats with that shared key,
both measured rather than assumed:

  * It caps every response at 10 records regardless of the `limit` asked for
    (`total` still reports the true match count, so the UI can say "showing
    10 of 162"). A free personal key from data.gov.in lifts this.
  * It is shared by every developer reading those docs, rate-limited
    accordingly, and revocable at any time.

Commodity names are Agmarknet's own vocabulary, not the free-text crop names
farmers type into this app — "Soybean" matches 0 records, "Soyabean" matches
162. `COMMODITY_ALIASES` below maps the app's crop vocabulary onto the real
names; every entry in it was verified against the live API rather than
guessed.
"""
import urllib.parse
from datetime import datetime
from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.cache import cache_get, cache_set

settings = get_settings()

_RESOURCE_ID = "9ef84268-d588-465a-a308-a864a43d0070"  # Current daily mandi prices

# data.gov.in silently stalls requests sent with httpx's default
# "python-httpx/..." User-Agent — the connection just hangs until it times
# out, with no error to explain why. An honest client identifier gets an
# immediate 200. Diagnosed by testing UAs against the live API; do not remove.
_HEADERS = {"User-Agent": "KrushiSarthi/1.0 (agricultural advisory app)"}

# App crop name (lowercased) -> Agmarknet's exact commodity name. Each of
# these was confirmed to return records from the live API; an unmapped crop
# falls back to title-casing whatever the farmer typed.
COMMODITY_ALIASES: dict[str, str] = {
    "soybean": "Soyabean",
    "soyabean": "Soyabean",
    "rice": "Paddy(Dhan)(Common)",
    "paddy": "Paddy(Dhan)(Common)",
    "wheat": "Wheat",
    "tomato": "Tomato",
    "onion": "Onion",
    "potato": "Potato",
    "cotton": "Cotton",
    "maize": "Maize",
    "corn": "Maize",
    "bajra": "Bajra(Pearl Millet/Cumbu)",
    "pearl millet": "Bajra(Pearl Millet/Cumbu)",
    "jowar": "Jowar(Sorghum)",
    "sorghum": "Jowar(Sorghum)",
    "groundnut": "Groundnut",
    "chickpea": "Bengal Gram(Gram)(Whole)",
    "gram": "Bengal Gram(Gram)(Whole)",
    "pigeonpeas": "Arhar (Tur/Red Gram)(Whole)",
    "tur": "Arhar (Tur/Red Gram)(Whole)",
    "arhar": "Arhar (Tur/Red Gram)(Whole)",
    "mungbean": "Green Gram (Moong)(Whole)",
    "moong": "Green Gram (Moong)(Whole)",
    "blackgram": "Black Gram (Urd Beans)(Whole)",
    "urad": "Black Gram (Urd Beans)(Whole)",
    "lentil": "Lentil(Masur)(Whole)",
    "masur": "Lentil(Masur)(Whole)",
    "banana": "Banana",
    "mango": "Mango",
    "grapes": "Grapes",
    "pomegranate": "Pomegranate",
    "papaya": "Papaya",
    "coconut": "Coconut",
    "orange": "Orange",
    "apple": "Apple",
    "watermelon": "Water Melon",
    "muskmelon": "Musk Melon",
    "coffee": "Coffee",
}


def normalize_commodity(crop: str) -> str:
    """Map a free-text crop name onto Agmarknet's vocabulary."""
    return COMMODITY_ALIASES.get(crop.strip().lower(), crop.strip().title())


def _parse_date(value: str | None) -> str | None:
    """Agmarknet returns dd/mm/yyyy; the app's contract wants ISO."""
    if not value:
        return None
    try:
        return datetime.strptime(value, "%d/%m/%Y").date().isoformat()
    except ValueError:
        return value


async def get_mandi_prices(
    db: Session,
    commodity: str | None = None,
    state: str | None = None,
    district: str | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Latest reported mandi prices, optionally filtered. Cached 12h per the
    plan's connector table — Agmarknet publishes once a day, so polling it
    harder just burns the shared API key's rate limit."""
    resolved = normalize_commodity(commodity) if commodity else None
    key = f"agmarknet:{resolved or '*'}:{state or '*'}:{district or '*'}:{limit}"
    cached = cache_get(db, key, settings.market_cache_ttl)
    if cached is not None:
        return cached

    params: dict[str, str] = {
        "api-key": settings.data_gov_api_key,
        "format": "json",
        "limit": str(limit),
    }
    # The API filters with filters[field]=value.
    if resolved:
        params["filters[commodity]"] = resolved
    if state:
        params["filters[state]"] = state
    if district:
        params["filters[district]"] = district

    url = f"https://api.data.gov.in/resource/{_RESOURCE_ID}?{urllib.parse.urlencode(params)}"
    async with httpx.AsyncClient(timeout=45.0, headers=_HEADERS) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        data = resp.json()

    records = data.get("records", [])
    result = [
        {
            "commodity": r.get("commodity"),
            "variety": r.get("variety"),
            "market": r.get("market"),
            "district": r.get("district"),
            "state": r.get("state"),
            "min_price": _to_float(r.get("min_price")),
            "max_price": _to_float(r.get("max_price")),
            "modal_price": _to_float(r.get("modal_price")),
            "arrival_date": _parse_date(r.get("arrival_date")),
        }
        for r in records
    ]
    cache_set(db, key, result)
    return result


def _to_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
