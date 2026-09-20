"""Pure functions: turn raw sensor/API numbers into the status labels and
estimates the UI displays. No I/O, no LLM — this is exactly the kind of
"not really ML" arithmetic described in docs/IMPLEMENTATION_PLAN.md section 1.

Honesty note on NPK: SoilGrids (the free global raster we use) publishes
nitrogen but does NOT publish phosphorus or potassium — no free global source
does at useful resolution. `estimate_phosphorus` / `estimate_potassium` below
are coarse pedotransfer-style estimates from organic carbon and texture, not
a lab measurement. They exist so the required SoilData fields are populated
with *something reasoned* rather than a fabricated-looking exact number, and
the API always attaches a note saying so. A real Soil Health Card test
(free, via the government scheme already listed in this app) is the accurate
alternative — see docs/IMPLEMENTATION_PLAN.md decision #1 re: IoT sensors.
"""


def classify_moisture(pct: float) -> str:
    if pct < 25:
        return "Low"
    if pct < 70:
        return "Good"
    return "High"


def classify_ph(ph: float) -> str:
    if ph < 5.5:
        return "Acidic"
    if ph <= 7.5:
        return "Normal"
    return "Alkaline"


def classify_temperature(celsius: float) -> str:
    if celsius < 15:
        return "Low"
    if celsius <= 35:
        return "Normal"
    return "High"


def classify_humidity(pct: float) -> str:
    if pct < 30:
        return "Low"
    if pct <= 70:
        return "Normal"
    return "High"


def overall_soil_status(moisture_status: str, ph_status: str) -> str:
    if moisture_status == "Low" or ph_status in ("Acidic", "Alkaline"):
        return "Needs Attention"
    return "Healthy"


def estimate_nitrogen_index(nitrogen_mg_kg: float | None) -> float:
    """SoilGrids nitrogen is total N in mg/kg (cg/kg / 10). Map to a rough
    0-100 field-relevant index (typical agricultural topsoil ~500-2500 mg/kg)."""
    if nitrogen_mg_kg is None:
        return 40.0  # unknown -> mid-range placeholder, never silently zero
    return round(min(max((nitrogen_mg_kg - 300) / 20, 5), 100), 1)


def estimate_phosphorus(soc_pct: float | None, clay_pct: float | None) -> float:
    """Coarse estimate, not a lab value — see module docstring."""
    soc = soc_pct if soc_pct is not None else 1.0
    clay = clay_pct if clay_pct is not None else 25.0
    return round(min(max(15 + soc * 8 - clay * 0.15, 5), 80), 1)


def estimate_potassium(clay_pct: float | None, sand_pct: float | None) -> float:
    """Coarse estimate, not a lab value — see module docstring. Clay-rich
    soils generally hold more exchangeable potassium than sandy soils."""
    clay = clay_pct if clay_pct is not None else 25.0
    sand = sand_pct if sand_pct is not None else 40.0
    return round(min(max(20 + clay * 0.6 - sand * 0.1, 8), 90), 1)
