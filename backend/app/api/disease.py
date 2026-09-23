"""Disease detection — Phase 2 of docs/IMPLEMENTATION_PLAN.md.

Cascade today: quality gate -> local ViT -> tiered answer (see
app/ml/disease/cascade.py). Stages [2] VLM second opinion and [3] paid API
fallback are not wired up — they need API keys/spend this deployment doesn't
have configured.
"""
import uuid
from datetime import datetime, timezone
from io import BytesIO

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from PIL import Image, UnidentifiedImageError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.db.database import get_db
from app.db.models import DiseaseScan, User
from app.ml.disease.cascade import run_cascade
from app.ml.disease.quality import QualityRejected
from app.schemas import DiseaseAlternativeOut, DiseaseDetectionOut

router = APIRouter(prefix="/disease", tags=["disease"])

_UPLOAD_DIR = get_settings().static_dir / "uploads" / "disease"
_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
_HISTORY_LIMIT = 50


def _image_url(request: Request, filename: str) -> str:
    return f"{str(request.base_url).rstrip('/')}/static/uploads/disease/{filename}"


@router.post("/detect", response_model=DiseaseDetectionOut)
async def detect_disease(
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DiseaseDetectionOut:
    raw = await file.read()
    if len(raw) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Image too large (max 10 MB).")

    try:
        image = Image.open(BytesIO(raw))
        image.load()
    except UnidentifiedImageError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Not a valid image file.") from exc

    try:
        result = run_cascade(image)
    except QualityRejected as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc

    filename = f"{uuid.uuid4().hex}.jpg"
    image.convert("RGB").save(_UPLOAD_DIR / filename, format="JPEG", quality=85)

    scanned_at = datetime.now(timezone.utc)
    scan = DiseaseScan(
        id=str(uuid.uuid4()),
        user_id=user.id,
        disease=result.disease,
        confidence=result.confidence,
        crop=result.crop,
        description=result.description,
        symptoms=result.symptoms,
        recommendation=result.recommendation,
        image_path=filename,
        scanned_at=scanned_at,
    )
    db.add(scan)
    db.commit()

    return DiseaseDetectionOut(
        disease=result.disease,
        confidence=result.confidence,
        crop=result.crop,
        description=result.description,
        symptoms=result.symptoms,
        recommendation=result.recommendation,
        image_url=_image_url(request, filename),
        scanned_at=scanned_at,
        certainty=result.certainty,
        caution=result.caution,
        alternatives=[
            DiseaseAlternativeOut(disease=a.disease, confidence=a.confidence, symptoms=a.symptoms)
            for a in result.alternatives
        ],
    )


@router.get("/history", response_model=list[DiseaseDetectionOut])
async def disease_history(
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[DiseaseDetectionOut]:
    scans = (
        db.query(DiseaseScan)
        .filter(DiseaseScan.user_id == user.id)
        .order_by(DiseaseScan.scanned_at.desc())
        .limit(_HISTORY_LIMIT)
        .all()
    )
    return [
        DiseaseDetectionOut(
            disease=s.disease,
            confidence=s.confidence,
            crop=s.crop,
            description=s.description,
            symptoms=s.symptoms,
            recommendation=s.recommendation,
            image_url=_image_url(request, s.image_path),
            scanned_at=s.scanned_at,
        )
        for s in scans
    ]
