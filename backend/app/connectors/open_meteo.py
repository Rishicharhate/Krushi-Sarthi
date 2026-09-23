"""Open-Meteo connector — free weather + ET0 + soil moisture, no API key,
non-commercial cap of 10,000 calls/day. https://open-meteo.com/

Every call in this module is cached (see app/db/cache.py) so a farm's card
refreshing on screen-open doesn't burn the daily quota.
"""
from datetime import datetime, timezone
from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.cache import cache_get, cache_set

settings = get_settings()


def _round(v: float) -> float:
    # ~1.1km precision is deliberately coarse: Open-Meteo's weather grids are
    # 1-11km, so nearby farms genuinely share the same weather and should
    # share the cache entry. (Finer rounding is used for SoilGrids and
    # Sentinel-2, whose grids are 250m and 10m.)
    return round(v, 2)


async def _get_json(url: str, params: dict[str, Any]) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()


async def get_current_weather(db: Session, lat: float, lon: float) -> dict[str, Any]:
    """Current temperature, humidity, rainfall, wind — for /api/environment/current."""
    key = f"om:current:{_round(lat)}:{_round(lon)}"
    cached = cache_get(db, key, settings.weather_cache_ttl)
    if cached is not None:
        return cached

    data = await _get_json(
        settings.open_meteo_forecast_url,
        {
            "latitude": lat,
            "longitude": lon,
            "current": ",".join([
                "temperature_2m",
                "relative_humidity_2m",
                "precipitation",
                "wind_speed_10m",
            ]),
            "timezone": "Asia/Kolkata",
        },
    )
    current = data["current"]
    result = {
        "temperature": current["temperature_2m"],
        "humidity": current["relative_humidity_2m"],
        "rainfall": current["precipitation"],
        "wind_speed": current["wind_speed_10m"],
        "updated_at": current["time"],
    }
    cache_set(db, key, result)
    return result


async def get_weather_history(
    db: Session, lat: float, lon: float, field: str, days: int = 7
) -> list[dict[str, Any]]:
    """Hourly-aggregated-to-daily history for the last `days` days.

    `field` is 'temperature' or 'humidity' (matches selectedEnvParamProvider
    in the Flutter app).
    """
    key = f"om:history:{field}:{_round(lat)}:{_round(lon)}:{days}"
    cached = cache_get(db, key, settings.weather_cache_ttl)
    if cached is not None:
        return cached

    daily_var = "temperature_2m_mean" if field == "temperature" else "relative_humidity_2m_mean"
    data = await _get_json(
        settings.open_meteo_archive_url,
        {
            "latitude": lat,
            "longitude": lon,
            "daily": daily_var,
            "past_days": days,
            "forecast_days": 0,
            "timezone": "Asia/Kolkata",
        },
    )
    daily = data.get("daily", {})
    times = daily.get("time", [])
    values = daily.get(daily_var, [])
    result = [
        {"timestamp": t, "value": v}
        for t, v in zip(times, values)
        if v is not None
    ]
    cache_set(db, key, result)
    return result


async def get_soil_moisture(db: Session, lat: float, lon: float) -> dict[str, Any] | None:
    """Top-layer (0-7cm) soil moisture, m3/m3, converted to a 0-100 index."""
    key = f"om:soilmoist:{_round(lat)}:{_round(lon)}"
    cached = cache_get(db, key, settings.weather_cache_ttl)
    if cached is not None:
        return cached

    data = await _get_json(
        settings.open_meteo_forecast_url,
        {
            "latitude": lat,
            "longitude": lon,
            "current": "soil_moisture_0_to_1cm,soil_temperature_0cm",
            "timezone": "Asia/Kolkata",
        },
    )
    current = data.get("current", {})
    moisture_m3m3 = current.get("soil_moisture_0_to_1cm")
    if moisture_m3m3 is None:
        return None
    result = {
        # Open-Meteo reports volumetric water content (m3/m3, typically 0-0.5+);
        # scale to a 0-100 "percent full" index the UI already expects.
        "moisture_pct": round(min(moisture_m3m3 * 200, 100), 1),
        "soil_temperature": current.get("soil_temperature_0cm"),
        "updated_at": current.get("time"),
    }
    cache_set(db, key, result)
    return result


async def get_soil_moisture_history(
    db: Session, lat: float, lon: float, days: int = 7
) -> list[dict[str, Any]]:
    """Daily-mean topsoil moisture for the last `days` days, from the archive
    API's hourly soil_moisture_0_to_7cm field, converted to the same 0-100
    index used by get_soil_moisture()."""
    key = f"om:soilmoisthist:{_round(lat)}:{_round(lon)}:{days}"
    cached = cache_get(db, key, settings.weather_cache_ttl)
    if cached is not None:
        return cached

    data = await _get_json(
        settings.open_meteo_archive_url,
        {
            "latitude": lat,
            "longitude": lon,
            "hourly": "soil_moisture_0_to_7cm",
            "past_days": days,
            "forecast_days": 0,
            "timezone": "Asia/Kolkata",
        },
    )
    hourly = data.get("hourly", {})
    times = hourly.get("time", [])
    values = hourly.get("soil_moisture_0_to_7cm", [])

    # Bucket hourly readings by calendar day and average them.
    by_day: dict[str, list[float]] = {}
    for t, v in zip(times, values):
        if v is None:
            continue
        day = t[:10]
        by_day.setdefault(day, []).append(v)

    result = [
        {"timestamp": day, "value": round(min(sum(vals) / len(vals) * 200, 100), 1)}
        for day, vals in sorted(by_day.items())
    ]
    cache_set(db, key, result)
    return result


async def get_et0(db: Session, lat: float, lon: float, days: int = 7) -> dict[str, Any]:
    """FAO-56 reference evapotranspiration + rainfall — feeds the irrigation
    water-balance calculation in app/agronomy/water_balance.py."""
    key = f"om:et0:{_round(lat)}:{_round(lon)}:{days}"
    cached = cache_get(db, key, settings.weather_cache_ttl)
    if cached is not None:
        return cached

    data = await _get_json(
        settings.open_meteo_forecast_url,
        {
            "latitude": lat,
            "longitude": lon,
            "daily": "et0_fao_evapotranspiration,precipitation_sum",
            "forecast_days": days,
            "timezone": "Asia/Kolkata",
        },
    )
    daily = data.get("daily", {})
    result = {
        "time": daily.get("time", []),
        "et0_mm": daily.get("et0_fao_evapotranspiration", []),
        "rainfall_mm": daily.get("precipitation_sum", []),
        "fetched_at": datetime.now(timezone.utc).isoformat(),
    }
    cache_set(db, key, result)
    return result
