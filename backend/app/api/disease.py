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
from app.db.models import DiseaseFeedback, DiseaseScan, User
from app.ml.disease import dataset, loader
from app.ml.disease.cascade import run_cascade
from app.ml.disease.labels import DISEASE_INFO
from app.ml.disease.quality import QualityRejected
from app.schemas import (
    DiseaseAlternativeOut, DiseaseDetectionOut, DiseaseFeedbackIn, DiseaseFeedbackOut,
    DiseaseLabelOut,
)

router = APIRouter(prefix="/disease", tags=["disease"])

settings = get_settings()
_UPLOAD_DIR = settings.static_dir / "uploads" / "disease"
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
        scan_id=scan.id,
        feedback_enabled=settings.feedback_mode,
    )


@router.get("/labels", response_model=list[DiseaseLabelOut])
async def disease_labels() -> list[DiseaseLabelOut]:
    """Every class the model can predict — the picker a tester chooses the
    true disease from, so feedback always uses the model's own vocabulary."""
    return [
        DiseaseLabelOut(label=label, display_name=info.get("display_name") or label, crop=info.get("crop"))
        for label, info in DISEASE_INFO.items()
    ]


@router.post("/feedback", response_model=DiseaseFeedbackOut)
async def disease_feedback(
    body: DiseaseFeedbackIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DiseaseFeedbackOut:
    """Testing-phase only (FEEDBACK_MODE): record whether a diagnosis was
    right, and if not, what it really was. Nothing is learned here — the
    photo is filed into the labelled dataset (app/ml/disease/dataset.py),
    which feeds app/ml/disease/retrain.py, which only replaces the
    model if it scores better on the held-out field photos."""
    if not settings.feedback_mode:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Feedback collection is disabled on this server.")

    scan = db.get(DiseaseScan, body.scan_id)
    if scan is None or scan.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Scan not found.")
    if body.true_label is not None and body.true_label not in DISEASE_INFO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Unknown label: {body.true_label}")
    if not body.is_correct and body.true_label is None and not (body.note or "").strip():
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Pick the correct disease, or describe it in the note if it isn't in the list.",
        )

    # The scan row stores the farmer-facing name ("Likely …"), not the class,
    # so re-run the model on the saved photo to get the exact predicted label.
    with Image.open(_UPLOAD_DIR / scan.image_path) as img:
        predicted = loader.predict(img, top_k=1)[0][0]
    true_label = predicted if body.is_correct else body.true_label

    fb = db.get(DiseaseFeedback, scan.id) or DiseaseFeedback(scan_id=scan.id)
    fb.predicted_label = predicted
    fb.is_correct = body.is_correct
    fb.true_label = true_label
    fb.note = body.note
    db.add(fb)
    db.commit()
    # File the photo under its label, building the ImageFolder dataset
    # retrain.py trains on (app/ml/disease/dataset.py).
    dataset.save(scan.id, _UPLOAD_DIR / scan.image_path, true_label, body.note)

    total = db.query(DiseaseFeedback).count()
    usable = db.query(DiseaseFeedback).filter(DiseaseFeedback.true_label.isnot(None)).count()
    return DiseaseFeedbackOut(
        scan_id=scan.id,
        predicted_label=predicted,
        true_label=true_label,
        is_correct=body.is_correct,
        total_feedback=total,
        usable_for_training=usable,
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
