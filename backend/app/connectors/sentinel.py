"""Sentinel-2 NDVI connector — real satellite crop health, **no account and
no API key required**.

The plan (docs/IMPLEMENTATION_PLAN.md §4) routes this through Copernicus Data
Space, which needs a free-but-registered account and burns a Processing Unit
budget. It turns out there's a second route with neither: Sentinel-2 L2A is
mirrored on AWS Open Data as Cloud-Optimized GeoTIFFs, searchable through the
public Earth Search STAC API and readable anonymously over HTTP range
requests. Because COGs are internally tiled, a windowed read of a ~200m box
around one farm fetches a few KB instead of the 100MB+ full band.

**Cloud masking is not optional here.** Sentinel-2 sees the ground only when
there are no clouds in the way, and over an Indian monsoon this can mean no
usable view for weeks. Every reading is therefore masked with the scene
classification (SCL) band and rejected if too few pixels over the field are
actually clear — the caller gets "no clear view since <date>" instead of an
NDVI number that is really measuring cloud shadow. Reporting a cloud-shadow
NDVI as crop health would be the same class of error as a confident wrong
disease diagnosis.
"""
import asyncio
import json
import os
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any

import numpy as np
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.cache import cache_get, cache_set

settings = get_settings()

# GDAL/rasterio need these to read public S3 COGs anonymously and to avoid
# listing the whole bucket directory on every open.
os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
os.environ.setdefault("AWS_NO_SIGN_REQUEST", "YES")
os.environ.setdefault("GDAL_HTTP_MAX_RETRY", "3")
os.environ.setdefault("GDAL_HTTP_RETRY_DELAY", "1")

# SCL (scene classification) values that mean "this pixel is not a usable
# view of the ground": 0 no-data, 1 saturated, 3 cloud shadow, 8 cloud
# medium probability, 9 cloud high probability, 10 thin cirrus, 11 snow.
_SCL_BAD = {0, 1, 3, 8, 9, 10, 11}
_MIN_CLEAR_FRACTION = 0.4  # below this, the field is too obscured to trust

_WINDOW_HALF_PX = 10  # 10m pixels -> ~210m box centred on the farm


def _round(v: float) -> float:
    return round(v, 2)


def _search_scenes(lat: float, lon: float, days: int) -> list[dict[str, Any]]:
    """STAC search for recent scenes over the point. Unauthenticated."""
    start = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%dT00:00:00Z")
    body = json.dumps({
        "collections": ["sentinel-2-l2a"],
        "intersects": {"type": "Point", "coordinates": [lon, lat]},
        "datetime": f"{start}/{datetime.now(timezone.utc).strftime('%Y-%m-%dT23:59:59Z')}",
        "limit": 30,
        "sortby": [{"field": "properties.datetime", "direction": "desc"}],
    }).encode()
    req = urllib.request.Request(
        settings.stac_search_url, data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.load(resp).get("features", [])


def _read_ndvi_from_scene(scene: dict[str, Any], lat: float, lon: float) -> dict[str, Any] | None:
    """Windowed read of red/nir/scl for one scene. Returns None when the
    field is too cloud-obscured in this scene to give an honest number.

    Blocking (rasterio/GDAL) — callers run this in a thread."""
    import rasterio
    from rasterio.warp import transform as warp_transform
    from rasterio.windows import Window

    assets = scene.get("assets", {})
    if not all(band in assets for band in ("red", "nir", "scl")):
        return None

    def read(href: str, half_px: int) -> np.ndarray:
        with rasterio.open(href) as src:
            xs, ys = warp_transform("EPSG:4326", src.crs, [lon], [lat])
            row, col = src.index(xs[0], ys[0])
            window = Window(col - half_px, row - half_px, half_px * 2 + 1, half_px * 2 + 1)
            return src.read(1, window=window, boundless=True, fill_value=0)

    red = read(assets["red"]["href"], _WINDOW_HALF_PX).astype("float32")
    nir = read(assets["nir"]["href"], _WINDOW_HALF_PX).astype("float32")
    # SCL ships at 20m, so half the window size covers the same ground.
    scl = read(assets["scl"]["href"], max(_WINDOW_HALF_PX // 2, 1)).astype("int16")

    clear_mask = ~np.isin(scl, list(_SCL_BAD))
    clear_fraction = float(clear_mask.mean()) if clear_mask.size else 0.0
    if clear_fraction < _MIN_CLEAR_FRACTION:
        return None

    # Upsample the 20m clear mask onto the 10m NDVI grid, then trim both to a
    # common shape (integer-ratio resampling can overshoot by a pixel).
    upsampled = np.kron(clear_mask, np.ones((2, 2), dtype=bool))
    rows = min(red.shape[0], upsampled.shape[0])
    cols = min(red.shape[1], upsampled.shape[1])
    red, nir = red[:rows, :cols], nir[:rows, :cols]
    mask = upsampled[:rows, :cols]

    denominator = nir + red
    valid = mask & (denominator > 0)
    if not valid.any():
        return None

    ndvi = (nir[valid] - red[valid]) / denominator[valid]
    return {
        "ndvi": round(float(np.median(ndvi)), 3),
        "date": scene["properties"]["datetime"][:10],
        "scene_id": scene["id"],
        "scene_cloud_cover": round(float(scene["properties"].get("eo:cloud_cover", -1)), 1),
        "clear_fraction": round(clear_fraction, 2),
        "source": "Sentinel-2 L2A (AWS Open Data), 10m, cloud-masked via SCL",
    }


def classify_ndvi(ndvi: float) -> str:
    """Standard NDVI interpretation for a growing crop. Matches the status
    vocabulary the Flutter StatusBadge already renders."""
    if ndvi < 0.2:
        return "Poor"
    if ndvi < 0.4:
        return "Moderate"
    if ndvi < 0.6:
        return "Good"
    return "Healthy"


async def get_ndvi_series(
    db: Session, lat: float, lon: float, days: int = 60, max_points: int = 8
) -> list[dict[str, Any]]:
    """Cloud-masked NDVI readings over the last `days`, newest first. Returns
    [] when the field has had no clear satellite view in that window — that's
    a real answer during monsoon, not a failure.

    Cached for a full satellite revisit cycle: re-reading COGs is the slow
    part, and the data genuinely doesn't change until the next overpass."""
    key = f"sentinel:ndvi:{_round(lat)}:{_round(lon)}:{days}:{max_points}"
    cached = cache_get(db, key, settings.ndvi_cache_ttl)
    if cached is not None:
        return cached

    scenes = await asyncio.to_thread(_search_scenes, lat, lon, days)
    # Cheapest scenes first: low scene-wide cloud cover is a good prior for
    # "this field will be clear", so we spend COG reads where they'll pay off.
    scenes.sort(key=lambda s: s["properties"].get("eo:cloud_cover", 100))

    results: list[dict[str, Any]] = []
    seen_dates: set[str] = set()
    for scene in scenes:
        if len(results) >= max_points:
            break
        date = scene["properties"]["datetime"][:10]
        if date in seen_dates:
            continue
        try:
            reading = await asyncio.to_thread(_read_ndvi_from_scene, scene, lat, lon)
        except Exception:  # noqa: BLE001 — one unreadable scene shouldn't kill the series
            continue
        if reading is not None:
            reading["health_status"] = classify_ndvi(reading["ndvi"])
            results.append(reading)
            seen_dates.add(date)

    results.sort(key=lambda r: r["date"], reverse=True)
    cache_set(db, key, results)
    return results


async def get_latest_ndvi(db: Session, lat: float, lon: float, days: int = 60) -> dict[str, Any] | None:
    """Most recent cloud-free NDVI reading, with the change since the
    previous clear pass. None when there's been no clear view at all."""
    series = await get_ndvi_series(db, lat, lon, days=days)
    if not series:
        return None

    latest = dict(series[0])
    if len(series) > 1:
        previous = series[1]["ndvi"]
        latest["previous_ndvi"] = previous
        latest["ndvi_change"] = round(latest["ndvi"] - previous, 3)
    return latest
