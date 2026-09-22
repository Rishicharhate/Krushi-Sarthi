"""Node functions for the farm advisory graph (see graph.py for the wiring).

Specialist nodes (weather/soil/disease) are deterministic — they call
tools.py and produce findings, no LLM involved. The LLM only appears in
synthesis (interpretation) and the writer (natural language), per
docs/IMPLEMENTATION_PLAN.md §3.3 rule #1: "Agronomy math lives in Python, not
in the LLM. The model decides what to look at and how to say it. It never
computes ET0 or NDVI in its head." The safety gate is a deterministic keyword
check for the same reason — a dosage recommendation shouldn't hinge on
whether an LLM call happened to flag itself.
"""
from app.agent import tools
from app.agent.llm import get_llm
from app.agent.state import FarmState
from app.db.database import SessionLocal


async def weather_node(state: FarmState) -> dict:
    farm = state["farm"]
    db = SessionLocal()
    try:
        result = await tools.fetch_weather_and_irrigation(
            db, farm["latitude"], farm["longitude"], farm["crop"]
        )
    finally:
        db.close()

    current = result["current"]
    irrigation = result["irrigation"]
    findings = [
        {
            "domain": "weather",
            "summary": (
                f"Currently {current['temperature']:.1f}°C, {current['humidity']:.0f}% humidity, "
                f"{current['rainfall']:.1f}mm rain in the last hour."
            ),
            "source": "Open-Meteo current weather",
        },
        {
            "domain": "irrigation",
            "summary": (
                f"Over the next {irrigation['days']} days: crop water use "
                f"~{irrigation['crop_water_use_mm']}mm (Kc={irrigation['kc_used']} for {farm['crop']}), "
                f"effective rainfall ~{irrigation['effective_rainfall_mm']}mm "
                f"-> irrigation need ~{irrigation['irrigation_need_mm']}mm."
            ),
            "source": "FAO-56 water balance (app/agronomy/water_balance.py) on Open-Meteo ET0 + rainfall forecast",
        },
    ]
    return {"weather": result, "irrigation": irrigation, "findings": findings}


async def soil_node(state: FarmState) -> dict:
    farm = state["farm"]
    db = SessionLocal()
    try:
        soil = await tools.fetch_soil(db, farm["latitude"], farm["longitude"])
    finally:
        db.close()

    findings = []
    if soil.get("moisture_pct") is not None:
        findings.append({
            "domain": "soil",
            "summary": f"Soil moisture {soil['moisture_pct']:.0f}% ({soil['moisture_status']}).",
            "source": "Open-Meteo soil moisture (0-1cm)",
        })
    if soil.get("ph") is not None:
        findings.append({
            "domain": "soil",
            "summary": f"Soil pH {soil['ph']:.1f} ({soil['ph_status']}).",
            "source": "SoilGrids v2 (ISRIC), 250m modelled baseline",
        })
    return {"soil": soil, "findings": findings}


async def disease_node(state: FarmState) -> dict:
    db = SessionLocal()
    try:
        scans = tools.fetch_recent_disease_scans(db, state["user_id"])
    finally:
        db.close()

    if not scans:
        return {"disease": None, "findings": []}

    latest = scans[0]
    findings = [{
        "domain": "disease",
        "summary": (
            f"Most recent leaf scan ({latest['scanned_at'][:10]}): "
            f"{latest['disease']} at {latest['confidence']:.0f}% confidence."
        ),
        "source": "On-device disease scan history (app/ml/disease/)",
    }]
    return {"disease": latest, "findings": findings}


_SYNTHESIS_PROMPT = """You are an agronomy assistant correlating field data for an Indian farmer's {crop} crop.
Given these findings, write 2-4 SHORT bullet points connecting anything that matters together
(e.g. low soil moisture + high water need + no rain forecast = irrigation is urgent; do not just
repeat findings that don't interact with each other). Do not invent numbers that aren't present in
the findings below. If nothing meaningfully correlates, say so briefly.

Findings:
{findings}

Farmer's question: {question}
"""


async def synthesis_node(state: FarmState) -> dict:
    findings_text = "\n".join(f"- [{f['domain']}] {f['summary']}" for f in state["findings"]) or "(none)"
    llm = get_llm()
    prompt = _SYNTHESIS_PROMPT.format(
        crop=state["farm"]["crop"], findings=findings_text, question=state["question"]
    )
    response = await llm.ainvoke(prompt)
    return {"synthesis": response.content}


_WRITER_PROMPT = """You are KrushiSarthi, an agricultural advisor for Indian farmers. Answer the farmer's
question directly and honestly, in plain English, using ONLY the facts given below. Cite specific numbers
from the findings. If the findings don't actually answer the question, say what's missing instead of
guessing. Keep it under 120 words. End with one concrete recommended action.

Farmer's question: {question}
Crop: {crop}

Findings:
{findings}

Correlated analysis:
{synthesis}
"""


async def writer_node(state: FarmState) -> dict:
    findings_text = "\n".join(f"- [{f['domain']}] {f['summary']}" for f in state["findings"]) or "(none)"
    llm = get_llm()
    prompt = _WRITER_PROMPT.format(
        question=state["question"],
        crop=state["farm"]["crop"],
        findings=findings_text,
        synthesis=state.get("synthesis", ""),
    )
    response = await llm.ainvoke(prompt)
    return {"answer": response.content}


# Deterministic keyword gate, not an LLM call — "safety gate on dosages"
# (docs/IMPLEMENTATION_PLAN.md §3.2) shouldn't depend on the writer LLM
# happening to flag its own output.
_HIGH_STAKES_TERMS = [
    "pesticide", "insecticide", "fungicide dose", "dosage", "ppm", "ml/l", "g/l",
    "uproot", "burn the crop", "destroy the crop", "toxic",
]


def safety_gate_node(state: FarmState) -> dict:
    text = state["answer"].lower()
    hit = next((term for term in _HIGH_STAKES_TERMS if term in text), None)
    if hit is None:
        return {"needs_human": False, "safety_note": None}
    note = (
        "This answer mentions chemical dosage or a destructive action "
        f"(matched: '{hit}'). Verify with your local Krishi Vigyan Kendra "
        "before acting — do not apply this alone."
    )
    return {"needs_human": True, "safety_note": note}
