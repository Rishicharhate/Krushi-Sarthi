"""Pydantic request/response models. Field names and shapes here are chosen to
match the Dart `fromJson`/`toJson` methods in lib/shared/models/*.dart
exactly — this file IS the contract, so if you change a field here, update
the matching Dart model in the same commit.
"""
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AuthRegisterRequest(BaseModel):
    device_id: str
    name: str | None = None


class AuthResponse(BaseModel):
    token: str
    user_id: str


# ── Farm ── (mirrors lib/shared/models/farm.dart)
class FarmIn(BaseModel):
    name: str
    location: str | None = None
    area: float
    area_unit: str = "Acres"
    crop: str
    sowing_date: datetime | None = None
    soil_type: str | None = None
    is_active: bool = False
    latitude: float | None = None
    longitude: float | None = None


class FarmOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    location: str | None
    area: float
    area_unit: str
    crop: str
    sowing_date: datetime | None
    soil_type: str | None
    is_active: bool
    latitude: float | None
    longitude: float | None


# ── Environment ── (mirrors lib/shared/models/environment_data.dart)
class EnvironmentDataOut(BaseModel):
    temperature: float
    humidity: float
    rainfall: float
    wind_speed: float
    temperature_status: str | None = None
    humidity_status: str | None = None
    updated_at: datetime


class EnvironmentHistoryPointOut(BaseModel):
    timestamp: datetime
    value: float


# ── Soil ── (mirrors lib/shared/models/soil_data.dart)
class SoilDataOut(BaseModel):
    moisture: float
    temperature: float
    ph: float
    nitrogen: float
    phosphorus: float
    potassium: float
    moisture_status: str | None = None
    ph_status: str | None = None
    overall_status: str | None = None
    updated_at: datetime


class SoilHistoryPointOut(BaseModel):
    timestamp: datetime
    value: float


class SoilInsightOut(BaseModel):
    message: str
    type: str


# ── Crop / fertilizer recommendation ── (Phase 3, mirrors
# lib/shared/models/recommendation.dart) — both models trained in
# app/ml/tabular/train.py.
class CropRecommendationIn(BaseModel):
    nitrogen: float
    phosphorous: float
    potassium: float
    temperature: float
    humidity: float
    ph: float
    rainfall: float


class RecommendationAlternativeOut(BaseModel):
    label: str
    confidence: float  # 0-100


class CropRecommendationOut(BaseModel):
    crop: str
    confidence: float  # 0-100
    alternatives: list[RecommendationAlternativeOut]


class FertilizerRecommendationIn(BaseModel):
    temperature: float
    humidity: float
    moisture: float
    nitrogen: float
    potassium: float
    phosphorous: float
    soil_type: str
    crop_type: str


class FertilizerRecommendationOut(BaseModel):
    fertilizer: str
    confidence: float  # 0-100
    alternatives: list[RecommendationAlternativeOut]


# ── Advisory agent ── (Phase 4, mirrors lib/shared/models/advisory.dart) —
# see app/agent/ for the LangGraph implementation.
class AdvisoryAskIn(BaseModel):
    farm_id: str
    question: str


class AdvisorySourceOut(BaseModel):
    domain: str
    summary: str
    source: str


class AdvisoryAskOut(BaseModel):
    answer: str
    needs_human: bool
    safety_note: str | None = None
    sources: list[AdvisorySourceOut]


# ── Crop health / NDVI ── (mirrors lib/shared/models/crop_health.dart) —
# real Sentinel-2, cloud-masked, see app/connectors/sentinel.py.
class CropHealthOut(BaseModel):
    ndvi: float
    health_status: str
    crop: str
    date: datetime
    image_url: str | None = None
    previous_ndvi: float | None = None
    ndvi_change: float | None = None


class NdviHistoryPointOut(BaseModel):
    date: datetime
    ndvi: float
    health_status: str | None = None


# ── Market prices ── (mirrors lib/shared/models/market_price.dart)
class MarketPriceOut(BaseModel):
    commodity: str | None = None
    variety: str | None = None
    market: str | None = None
    district: str | None = None
    state: str | None = None
    min_price: float | None = None
    max_price: float | None = None
    modal_price: float | None = None
    arrival_date: str | None = None


# ── Government schemes ── (Phase 5, mirrors
# lib/shared/models/government_scheme.dart) — corpus + semantic search in
# app/rag/.
class GovernmentSchemeOut(BaseModel):
    id: str
    name: str
    description: str
    eligibility: str
    benefits: str
    documents: list[str]
    application_url: str | None = None
    application_process: str | None = None
    category: str = "General"
    state: str | None = None
    updated_at: datetime


# ── Notifications ── (Phase 5, mirrors lib/shared/models/notification_item.dart)
class NotificationItemOut(BaseModel):
    id: str
    title: str
    message: str
    category: str
    timestamp: datetime
    is_read: bool = False
    icon: str | None = None


# ── Disease detection ── (mirrors lib/shared/models/disease_result.dart)
class DiseaseAlternativeOut(BaseModel):
    disease: str
    confidence: float  # 0-100
    symptoms: str | None = None


class DiseaseDetectionOut(BaseModel):
    disease: str
    confidence: float  # 0-100, NOT 0-1 — see app/ml/disease/cascade.py
    crop: str | None = None
    description: str | None = None
    symptoms: str | None = None
    recommendation: str | None = None
    image_url: str | None = None
    scanned_at: datetime
    # Only set on a fresh /detect response; history rows don't store them.
    certainty: str | None = None  # "high" | "medium" | "low"
    caution: str | None = None
    alternatives: list[DiseaseAlternativeOut] = []
