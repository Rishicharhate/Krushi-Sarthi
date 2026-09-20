"""SoilGrids v2 (ISRIC) connector — free global 250m soil raster, no API key.
https://rest.isric.org/  Fair use is ~5 calls/minute, so results are cached
for 30 days (see settings.soil_cache_ttl) — this is a static baseline, it
doesn't change day to day.

Important: this is a *modelled estimate*, not a sensor reading. The API layer
that consumes this must say so in the response rather than presenting it as
measured ground truth.
"""
from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.cache import cache_get, cache_set

settings = get_settings()

_PROPERTIES = ["phh2o", "nitrogen", "soc", "clay", "sand", "silt"]
_DEPTH = "0-5cm"  # topsoil, most relevant to a standing crop


def _round(v: float) -> float:
    return round(v, 2)


async def get_soil_profile(db: Session, lat: float, lon: float) -> dict[str, Any] | None:
    key = f"soilgrids:{_round(lat)}:{_round(lon)}"
    cached = cache_get(db, key, settings.soil_cache_ttl)
    if cached is not None:
        return cached

    params = [
        ("lon", lon),
        ("lat", lat),
        ("depth", _DEPTH),
        ("value", "mean"),
    ] + [("property", p) for p in _PROPERTIES]

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(settings.soilgrids_url, params=params)
        if resp.status_code != 200:
            return None
        data = resp.json()

    values: dict[str, float] = {}
    for layer in data.get("properties", {}).get("layers", []):
        name = layer.get("name")
        for depth_entry in layer.get("depths", []):
            if depth_entry.get("label") == _DEPTH:
                mean = depth_entry.get("values", {}).get("mean")
                if mean is not None:
                    values[name] = mean
                break

    if not values:
        return None

    # SoilGrids units: phh2o is pH*10, nitrogen is cg/kg, soc is dg/kg,
    # clay/sand/silt are g/kg (permille). Convert to the units the app displays.
    result = {
        "ph": values.get("phh2o", 0) / 10 if "phh2o" in values else None,
        "nitrogen_mg_kg": values.get("nitrogen", 0) / 10 if "nitrogen" in values else None,
        "soc_pct": values.get("soc", 0) / 100 if "soc" in values else None,
        "clay_pct": values.get("clay", 0) / 10 if "clay" in values else None,
        "sand_pct": values.get("sand", 0) / 10 if "sand" in values else None,
        "silt_pct": values.get("silt", 0) / 10 if "silt" in values else None,
        "source": "SoilGrids v2 (ISRIC), 250m modelled estimate, 0-5cm depth",
    }
    cache_set(db, key, result)
    return result
