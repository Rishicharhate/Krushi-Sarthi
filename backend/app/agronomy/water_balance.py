"""FAO-56-style irrigation water balance. Pure function, no I/O — this is the
exact kind of arithmetic docs/IMPLEMENTATION_PLAN.md §3.3 insists lives in
Python, never in an LLM: "It never computes ET0 or NDVI in its head. LLMs are
unreliable at arithmetic and you cannot defend a hallucinated irrigation
depth in a viva."

Method: crop water use over the period = sum(ET0_daily * Kc) (FAO-56 single
crop coefficient approach, mid-season Kc — a simplification; real FAO-56 also
adjusts Kc by growth stage). Irrigation need = crop water use minus effective
rainfall (rainfall is never 100% effective — some runs off or drains past the
root zone; 0.8 is a widely used rule-of-thumb effective-rainfall fraction for
row crops, not a per-soil calibration).
"""

# Rough, widely-published FAO-56 mid-season single crop coefficients (Kc) for
# common field crops. Not growth-stage-precise — good enough for a
# directional irrigation signal. Falls back to 1.0 (typical field-crop
# average) for any crop not in this table.
CROP_KC: dict[str, float] = {
    "rice": 1.20,
    "wheat": 1.15,
    "maize": 1.20,
    "cotton": 1.15,
    "sugarcane": 1.25,
    "soybean": 1.15,
    "groundnut": 1.10,
    "tomato": 1.15,
    "potato": 1.15,
    "onion": 1.05,
    "chickpea": 1.00,
    "mustard": 1.05,
    "sunflower": 1.10,
    "banana": 1.10,
    "grapes": 0.80,
}
DEFAULT_KC = 1.0
EFFECTIVE_RAINFALL_FRACTION = 0.8


def irrigation_need_mm(et0_mm: list[float], rainfall_mm: list[float], crop: str) -> dict:
    """`et0_mm` / `rainfall_mm`: daily values over the same period (e.g. the
    next N forecast days from Open-Meteo). Returns the water balance and the
    Kc actually used, so the caller can show its work."""
    kc = CROP_KC.get(crop.strip().lower(), DEFAULT_KC)
    crop_water_use = sum(e for e in et0_mm if e is not None) * kc
    effective_rainfall = sum(r for r in rainfall_mm if r is not None) * EFFECTIVE_RAINFALL_FRACTION
    deficit = crop_water_use - effective_rainfall
    return {
        "days": len(et0_mm),
        "kc_used": kc,
        "crop_water_use_mm": round(crop_water_use, 1),
        "effective_rainfall_mm": round(effective_rainfall, 1),
        "irrigation_need_mm": round(max(deficit, 0.0), 1),
    }
