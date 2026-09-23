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
import logging
import os
from functools import partial
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any

import numpy as np
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.cache import cache_get, cache_set

settings = get_settings()
logger = logging.getLogger(__name__)

# GDAL/rasterio tuning for reading public S3 COGs over the network. These
# matter a lot for latency: by default GDAL makes several small sequential
# range requests just to open a file (header, then overviews, then tiles),
# and that round-trip cost dominates when reading a tiny window from many
# scenes. Pulling a 32KB header in one go and allowing HTTP/2 multiplexing
# collapses most of those round trips.
os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
os.environ.setdefault("AWS_NO_SIGN_REQUEST", "YES")
os.environ.setdefault("GDAL_HTTP_MAX_RETRY", "2")
os.environ.setdefault("GDAL_HTTP_RETRY_DELAY", "1")
os.environ.setdefault("GDAL_INGESTED_BYTES_AT_OPEN", "32768")
os.environ.setdefault("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif")
os.environ.setdefault("GDAL_HTTP_VERSION", "2")
os.environ.setdefault("GDAL_HTTP_MULTIPLEX", "YES")
os.environ.setdefault("VSI_CACHE", "TRUE")
os.environ.setdefault("VSI_CACHE_SIZE", "5000000")

# SCL (scene classification) values that mean "this pixel is not a usable
# view of the ground": 0 no-data, 1 saturated, 3 cloud shadow, 8 cloud
# medium probability, 9 cloud high probability, 10 thin cirrus, 11 snow.
_SCL_BAD = {0, 1, 3, 8, 9, 10, 11}
_MIN_CLEAR_FRACTION = 0.4  # below this, the field is too obscured to trust

# 10m pixels -> ~90m box centred on the farm, i.e. roughly a 2-acre field.
# A wider box averages in the neighbours' crops: two fields 60m apart used to
# report the same NDVI because a 210m box covered both of them.
_WINDOW_HALF_PX = 4


def _round(v: float) -> float:
    # ~11m of precision, finer than one 10m Sentinel-2 pixel. Rounding to 2
    # decimals (~1.1km) made every farm within a kilometre share one cache
    # entry, so adjacent fields all got the same NDVI.
    return round(v, 4)


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


def _read_window(href: str, lat: float, lon: float, half_px: int) -> np.ndarray:
    """Blocking windowed COG read — only the bytes covering the window are
    fetched, via HTTP range requests."""
    import rasterio
    from rasterio.warp import transform as warp_transform
    from rasterio.windows import Window

    with rasterio.open(href) as src:
        xs, ys = warp_transform("EPSG:4326", src.crs, [lon], [lat])
        row, col = src.index(xs[0], ys[0])
        window = Window(col - half_px, row - half_px, half_px * 2 + 1, half_px * 2 + 1)
        return src.read(1, window=window, boundless=True, fill_value=0)


def _clear_mask(scene: dict[str, Any], lat: float, lon: float) -> tuple[np.ndarray, float] | None:
    """Read ONLY the scene-classification band and decide whether this scene
    is worth reading the spectral bands for.

    This ordering matters a lot for latency: during monsoon most scenes are
    rejected, and checking SCL first (one band, 20m) skips two further band
    reads per rejected scene."""
    assets = scene.get("assets", {})
    if not all(band in assets for band in ("red", "nir", "scl")):
        return None
    # SCL ships at 20m, so half the window size covers the same ground.
    scl = _read_window(assets["scl"]["href"], lat, lon, max(_WINDOW_HALF_PX // 2, 1)).astype("int16")
    mask = ~np.isin(scl, list(_SCL_BAD))
    fraction = float(mask.mean()) if mask.size else 0.0
    if fraction < _MIN_CLEAR_FRACTION:
        return None
    return mask, fraction


def _ndvi_from_mask(
    scene: dict[str, Any],
    lat: float,
    lon: float,
    clear_mask: np.ndarray,
    clear_fraction: float,
) -> dict[str, Any] | None:
    """Read red+nir for a scene already known to see the field, and compute
    cloud-masked NDVI. Split from the mask check so the caller can do all the
    cheap checks first and only pay for spectral reads where they'll count.

    Blocking (rasterio/GDAL) — callers run this in a thread."""
    assets = scene["assets"]
    red = _read_window(assets["red"]["href"], lat, lon, _WINDOW_HALF_PX).astype("float32")
    nir = _read_window(assets["nir"]["href"], lat, lon, _WINDOW_HALF_PX).astype("float32")

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


def _read_ndvi_from_scene(scene: dict[str, Any], lat: float, lon: float) -> dict[str, Any] | None:
    """Cheap cloud check first, spectral read only if the field is clear.
    Returns None when this scene genuinely doesn't see the field.

    Blocking (rasterio/GDAL) — callers run this in a thread."""
    checked = _clear_mask(scene, lat, lon)
    if checked is None:
        return None
    clear_mask, clear_fraction = checked
    return _ndvi_from_mask(scene, lat, lon, clear_mask, clear_fraction)


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


# Satellite reads are slow and variable from here (a single cold COG window
# read measured 2-10s, far more under contention), so they run in a
# background task per field rather than inside the request. Why: a request
# with its own deadline cannot actually stop a blocking GDAL read in a
# thread. The abandoned reads kept running, starved the thread pool, and
# made the *next* request time out even faster (measured: 45s, then 110s)
# while their results were thrown away. Background tasks run to completion,
# so every read that finishes gets cached.
_SCENE_TIMEOUT_S = 90
_READ_SEMAPHORE = asyncio.Semaphore(3)  # across all fields; more just contends
_REQUEST_WAIT_S = 20  # how long a request waits before saying "still fetching"
_PARTIAL_TTL_S = 60 * 60  # retry sooner when some scenes couldn't be read


class NdviPending(Exception):
    """A background fetch for this field is running; ask again shortly."""


# Distinguishes "the read failed/timed out" from "the read succeeded and this
# scene genuinely doesn't see the field". They must not be conflated: the
# second is a permanent fact worth caching forever, the first is a transient
# network condition that would otherwise get frozen into the cache as a
# permanent "cloudy" verdict for a scene that is actually fine.
_FAILED = object()


async def _guarded(coro_fn):
    """Run a blocking read in a thread under the shared concurrency limit and
    a per-scene timeout. Returns _FAILED on a transient failure, otherwise
    whatever the read returned (including a genuine None)."""
    async with _READ_SEMAPHORE:
        try:
            return await asyncio.wait_for(asyncio.to_thread(coro_fn), timeout=_SCENE_TIMEOUT_S)
        except asyncio.TimeoutError:
            logger.warning("Sentinel-2 scene read timed out after %ss", _SCENE_TIMEOUT_S)
            return _FAILED
        except Exception as exc:  # noqa: BLE001
            if "does not exist" in str(exc):
                # The band file is missing from the archive (seen for real on
                # one scene). That's permanent, not transient: treat it as
                # "this scene has no usable view" so it can't block caching
                # of the series forever.
                logger.info("Sentinel-2 asset missing, skipping scene: %s", exc)
                return None
            # Logged with a traceback on purpose. This handler once silently
            # swallowed a NameError from a renamed function, so every farm
            # reported "no cloud-free view" when the code was actually
            # crashing. Network failures and bugs look identical from here;
            # the log is what tells them apart.
            logger.warning("Sentinel-2 scene read failed", exc_info=True)
            return _FAILED


def _series_keys(lat: float, lon: float, days: int, max_points: int) -> tuple[str, str]:
    base = f"{_round(lat)}:{_round(lon)}:{days}:{max_points}"
    return f"sentinel:ndvi:{base}", f"sentinel:ndvi-partial:{base}"


def _scene_key(scene: dict[str, Any], lat: float, lon: float) -> str:
    return f"sentinel:scene:{scene['id']}:{_round(lat)}:{_round(lon)}"


async def _compute_series(
    lat: float, lon: float, days: int, max_points: int, max_scenes: int
) -> list[dict[str, Any]]:
    """The background job. Owns its own DB session because it outlives the
    request that started it."""
    from app.db.database import SessionLocal

    db = SessionLocal()
    try:
        scenes = await asyncio.to_thread(_search_scenes, lat, lon, days)

        # One scene per date, most recent first.
        #
        # Deliberately NOT ranked by scene-wide cloud cover. That looks like a
        # sensible prior but measurably is not: over the Shirpur test farm the
        # usable pass was a 73%-cloud scene (the field happened to sit in a
        # gap), while a 52%-cloud scene had the field under cloud shadow.
        # Ranking by scene cloud and truncating silently dropped the only good
        # reading. Checking the cheap SCL band for each candidate is what
        # makes the result deterministic.
        by_date: dict[str, dict[str, Any]] = {}
        for scene in sorted(scenes, key=lambda s: s["properties"]["datetime"], reverse=True):
            by_date.setdefault(scene["properties"]["datetime"][:10], scene)
        candidates = sorted(
            by_date.values(), key=lambda s: s["properties"]["datetime"], reverse=True
        )[:max_scenes]

        # Per-scene caching, per the plan's §4 rule: "Cache NDVI per
        # (geometry, date) and never fetch the same thing twice." A past pass
        # never changes, so each scene's verdict is cached permanently,
        # including the negative one, which is most of them in monsoon.
        results: list[dict[str, Any]] = []
        had_failure = False
        batch_size = 3
        for i in range(0, len(candidates), batch_size):
            batch = candidates[i:i + batch_size]
            to_read = []
            for scene in batch:
                hit = cache_get(db, _scene_key(scene, lat, lon), settings.scene_cache_ttl)
                if hit is None:
                    to_read.append(scene)
                elif hit.get("ndvi") is not None:
                    results.append(hit)

            readings = await asyncio.gather(*(
                _guarded(partial(_read_ndvi_from_scene, scene, lat, lon)) for scene in to_read
            ))
            for scene, reading in zip(to_read, readings):
                if reading is _FAILED:
                    had_failure = True  # transient: not cached, retried next run
                    continue
                cache_set(db, _scene_key(scene, lat, lon),
                          reading or {"ndvi": None, "scene_id": scene["id"]})
                if reading is not None:
                    results.append(reading)

            # Newest-first, so once we hold enough readings the rest can only
            # be older ones we wouldn't show anyway.
            if len(results) >= max_points:
                break

        for reading in results:
            reading["health_status"] = classify_ndvi(reading["ndvi"])
        results.sort(key=lambda r: r["date"], reverse=True)
        results = results[:max_points]

        full_key, partial_key = _series_keys(lat, lon, days, max_points)
        if had_failure and len(results) < max_points:
            # Some scenes couldn't be read. Serve what we have for a short
            # while, then try again, instead of freezing an incomplete answer
            # for a whole revisit cycle or leaving the screen on "fetching".
            cache_set(db, partial_key, results)
        else:
            cache_set(db, full_key, results)
        return results
    finally:
        db.close()


_inflight: dict[str, asyncio.Task] = {}


def _ensure_task(lat: float, lon: float, days: int, max_points: int, max_scenes: int) -> asyncio.Task:
    full_key, _ = _series_keys(lat, lon, days, max_points)
    task = _inflight.get(full_key)
    if task is None or task.done():
        task = asyncio.create_task(_compute_series(lat, lon, days, max_points, max_scenes))
        _inflight[full_key] = task

        def _done(t: asyncio.Task) -> None:
            _inflight.pop(full_key, None)
            if not t.cancelled() and t.exception() is not None:
                logger.warning("Sentinel-2 background fetch failed", exc_info=t.exception())

        task.add_done_callback(_done)
    return task


def prefetch(lat: float, lon: float, days: int = 90, max_points: int = 5) -> None:
    """Start fetching a field's NDVI without waiting, e.g. right after a farm
    is created, so the crop-health screen is ready by the time it's opened.
    Must be called from inside the running event loop."""
    from app.db.database import SessionLocal

    full_key, _ = _series_keys(lat, lon, days, max_points)
    db = SessionLocal()
    try:
        if cache_get(db, full_key, settings.ndvi_cache_ttl) is not None:
            return
    finally:
        db.close()
    _ensure_task(lat, lon, days, max_points, 20)


async def get_ndvi_series(
    db: Session,
    lat: float,
    lon: float,
    days: int = 90,
    max_points: int = 5,
    max_scenes: int = 20,
) -> list[dict[str, Any]]:
    """Cloud-masked NDVI readings over the last `days`, newest first. Returns
    [] when the field has had no clear satellite view in that window, which
    is a real answer during monsoon. Raises NdviPending when a background
    fetch is still running for this field."""
    full_key, partial_key = _series_keys(lat, lon, days, max_points)
    cached = cache_get(db, full_key, settings.ndvi_cache_ttl)
    if cached is not None:
        return cached
    partial_hit = cache_get(db, partial_key, _PARTIAL_TTL_S)
    if partial_hit is not None:
        return partial_hit

    task = _ensure_task(lat, lon, days, max_points, max_scenes)
    try:
        # shield(): if this request gives up waiting, the fetch keeps going.
        return await asyncio.wait_for(asyncio.shield(task), timeout=_REQUEST_WAIT_S)
    except asyncio.TimeoutError as exc:
        raise NdviPending() from exc


async def get_latest_ndvi(db: Session, lat: float, lon: float, days: int = 90) -> dict[str, Any] | None:
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
