"""Orchestrates the confidence-gated cascade from docs/IMPLEMENTATION_PLAN.md
§1.1: [0] quality gate -> [1] local model -> [4] tiered answer.

Stages [2] (VLM second opinion) and [3] (paid API fallback, e.g. Kindwise
crop.health) are deliberately not wired up yet — both need API keys/spend
this deployment isn't configured with. The extension point is the
`certainty != "high"` path below: insert stage [2] there, calling it only
when the local model isn't confident.
"""
from dataclasses import dataclass, field

from PIL import Image

from app.ml.disease import loader
from app.ml.disease.labels import DISEASE_INFO
from app.ml.disease.quality import check as check_quality

# Calibrated by measurement on 215 real field photos, not guessed — see
# backend/notebooks/disease_field_eval.json for the full sweep. The current
# model is *underconfident*: mean top-1 probability is ~0.53 even when it is
# correct, so a raw "38%" usually does not mean "probably wrong".
#
#   conf / margin -> coverage / precision-when-answered
#   0.30 / 0.00   ->   83.3%  /  80.4%   <- "medium" floor
#   0.40 / 0.20   ->   62.3%  /  88.8%   <- "high"
#   0.50 / 0.20   ->   51.6%  /  91.0%
#
# Rather than a single yes/no gate (which threw away the diagnosis, symptoms
# and treatment for ~38% of photos), answers are tiered:
#   high   — show the diagnosis as-is.
#   medium — show the diagnosis with its symptoms and treatment, plus a
#            "check the symptoms match before spraying" caution and the
#            runner-up diseases (top-3 accuracy is 94.4%, so the right answer
#            is almost always in the list).
#   low    — same info for the nearest match and alternatives, but the
#            recommendation is to retake the photo / consult a KVK.
HIGH_CONFIDENCE = 0.40
HIGH_MARGIN = 0.20
MEDIUM_CONFIDENCE = 0.30
_TOP_K = 3
_MIN_ALTERNATIVE_PROB = 0.05  # don't list near-zero noise as "possible"


@dataclass
class Alternative:
    disease: str
    confidence: float  # 0-100
    symptoms: str | None


@dataclass
class CascadeResult:
    disease: str
    confidence: float  # 0-100, matches the Dart DiseaseResult contract
    crop: str | None
    description: str | None
    symptoms: str | None
    recommendation: str | None
    certainty: str  # "high" | "medium" | "low"
    caution: str | None = None
    alternatives: list[Alternative] = field(default_factory=list)


def _certainty(top_prob: float, margin: float) -> str:
    if top_prob >= HIGH_CONFIDENCE and margin >= HIGH_MARGIN:
        return "high"
    if top_prob >= MEDIUM_CONFIDENCE:
        return "medium"
    return "low"


def run_cascade(image: Image.Image) -> CascadeResult:
    check_quality(image)  # raises QualityRejected on failure — caller maps to a 422

    predictions = loader.predict(image, top_k=_TOP_K)
    top_label, top_prob = predictions[0]
    second_prob = predictions[1][1] if len(predictions) > 1 else 0.0
    certainty = _certainty(top_prob, top_prob - second_prob)

    info = DISEASE_INFO.get(top_label, {})
    display_name = info.get("display_name", top_label)
    confidence = round(top_prob * 100, 1)

    if certainty == "high":
        return CascadeResult(
            disease=display_name,
            confidence=confidence,
            crop=info.get("crop"),
            description=info.get("description"),
            symptoms=info.get("symptoms"),
            recommendation=info.get("recommendation"),
            certainty="high",
        )

    alternatives = [
        Alternative(
            disease=DISEASE_INFO.get(label, {}).get("display_name", label),
            confidence=round(prob * 100, 1),
            symptoms=DISEASE_INFO.get(label, {}).get("symptoms"),
        )
        for label, prob in predictions[1:]
        if prob >= _MIN_ALTERNATIVE_PROB
    ]

    if certainty == "medium":
        return CascadeResult(
            disease=f"Likely {display_name}",
            confidence=confidence,
            crop=info.get("crop"),
            description=info.get("description"),
            symptoms=info.get("symptoms"),
            recommendation=info.get("recommendation"),
            certainty="medium",
            caution=(
                "This is the most likely match, but not a certain one. Compare "
                "the symptoms below with your leaf — and the other possibilities "
                "listed — before buying or spraying any chemical."
            ),
            alternatives=alternatives,
        )

    return CascadeResult(
        disease=f"Possibly {display_name}",
        confidence=confidence,
        crop=info.get("crop"),
        description=info.get("description"),
        symptoms=info.get("symptoms"),
        recommendation=(
            "Retake the photo in good light with a single leaf filling the frame "
            "against a plain background, or get a second opinion from your "
            "nearest Krishi Vigyan Kendra (KVK) before taking any action. "
            f"If the symptoms clearly match, the usual treatment is: "
            f"{info.get('recommendation') or 'see your local agriculture officer.'}"
        ),
        certainty="low",
        caution=(
            "The model could not identify this reliably. The nearest match and "
            "other possibilities are shown only to help you compare — do not "
            "treat based on this result alone."
        ),
        alternatives=alternatives,
    )
