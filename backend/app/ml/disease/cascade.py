"""Orchestrates the confidence-gated cascade from docs/IMPLEMENTATION_PLAN.md
§1.1: [0] quality gate -> [1] local model -> [4] honest decline.

Stages [2] (VLM second opinion) and [3] (paid API fallback, e.g. Kindwise
crop.health) are deliberately not wired up yet — both need API keys/spend
this deployment isn't configured with. The extension point is the
`if is_confident` branch below: insert stage [2] there, calling it only when
the local model isn't confident, before falling through to decline.
"""
from dataclasses import dataclass

from PIL import Image

from app.ml.disease import loader
from app.ml.disease.labels import DISEASE_INFO
from app.ml.disease.quality import check as check_quality

CONFIDENCE_THRESHOLD = 0.85
MARGIN_THRESHOLD = 0.20


@dataclass
class CascadeResult:
    disease: str
    confidence: float  # 0-100, matches the Dart DiseaseResult contract
    crop: str | None
    description: str | None
    symptoms: str | None
    recommendation: str | None
    is_confident: bool


def run_cascade(image: Image.Image) -> CascadeResult:
    check_quality(image)  # raises QualityRejected on failure — caller maps to a 422

    predictions = loader.predict(image, top_k=2)
    top_label, top_prob = predictions[0]
    second_prob = predictions[1][1] if len(predictions) > 1 else 0.0
    margin = top_prob - second_prob

    info = DISEASE_INFO.get(top_label, {})
    crop = info.get("crop")
    display_name = info.get("display_name", top_label)
    is_confident = top_prob >= CONFIDENCE_THRESHOLD and margin >= MARGIN_THRESHOLD

    if is_confident:
        return CascadeResult(
            disease=display_name,
            confidence=round(top_prob * 100, 1),
            crop=crop,
            description=info.get("description"),
            symptoms=info.get("symptoms"),
            recommendation=info.get("recommendation"),
            is_confident=True,
        )

    return CascadeResult(
        disease=f"Uncertain — possible {display_name}",
        confidence=round(top_prob * 100, 1),
        crop=crop,
        description=(
            "The model isn't confident enough to diagnose this photo reliably. "
            "Models trained on clean lab photos often struggle on real field "
            "photos — this is a known limitation, not a bug."
        ),
        symptoms=None,
        recommendation=(
            "Retake the photo in good light with a single leaf filling the frame "
            "against a plain background, or get a second opinion from your "
            "nearest Krishi Vigyan Kendra (KVK) before taking any action."
        ),
        is_confident=False,
    )
