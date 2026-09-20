"""Crop & fertilizer recommendation — Phase 3 of docs/IMPLEMENTATION_PLAN.md.
Two RandomForestClassifier models trained in app/ml/tabular/train.py and
served here as-is. See that file and notebooks/*_report.json for the
evaluation this project's report should cite (stratified split, 5-fold CV,
confusion matrix, feature importances).
"""
from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.db.models import User
from app.ml.tabular import loader
from app.schemas import (
    CropRecommendationIn,
    CropRecommendationOut,
    FertilizerRecommendationIn,
    FertilizerRecommendationOut,
    RecommendationAlternativeOut,
)

router = APIRouter(prefix="/recommend", tags=["recommend"])


@router.post("/crop", response_model=CropRecommendationOut)
async def recommend_crop(
    payload: CropRecommendationIn,
    user: User = Depends(get_current_user),
) -> CropRecommendationOut:
    ranked = loader.predict_crop(payload.model_dump())
    top_label, top_prob = ranked[0]
    return CropRecommendationOut(
        crop=top_label,
        confidence=round(top_prob * 100, 1),
        alternatives=[
            RecommendationAlternativeOut(label=label, confidence=round(prob * 100, 1))
            for label, prob in ranked[1:]
        ],
    )


@router.post("/fertilizer", response_model=FertilizerRecommendationOut)
async def recommend_fertilizer(
    payload: FertilizerRecommendationIn,
    user: User = Depends(get_current_user),
) -> FertilizerRecommendationOut:
    ranked = loader.predict_fertilizer(payload.model_dump())
    top_label, top_prob = ranked[0]
    return FertilizerRecommendationOut(
        fertilizer=top_label,
        confidence=round(top_prob * 100, 1),
        alternatives=[
            RecommendationAlternativeOut(label=label, confidence=round(prob * 100, 1))
            for label, prob in ranked[1:]
        ],
    )
