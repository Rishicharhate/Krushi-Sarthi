"""Stage [1] of the cascade — loads the disease-classification model once per
process and exposes a thin `predict()`. Never trusted on its own; see
cascade.py for the confidence gate that wraps it.

Model: `asafe51/plantdoc-disease-classifier` — a ViT fine-tuned on PlantDoc
(real in-field photographs). Chosen by measurement, not by model card: on 215
held-out real field photos it scored 73.0% top-1 / 94.4% top-3, against 18.6%
top-1 for the PlantVillage-trained MobileNetV2 this replaced. Full comparison
across 8 candidates: backend/notebooks/disease_field_eval.json.

Note that several PlantVillage-trained models advertise 99%+ accuracy on
their model cards and score close to 30% here — those numbers are measured on
lab photos with plain backgrounds, which is not what a farmer's camera
produces. Always re-measure on field data before trusting a checkpoint.
"""
import logging
import threading

import torch
from PIL import Image
from transformers import AutoImageProcessor, AutoModelForImageClassification

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_MODEL_REPO = "asafe51/plantdoc-disease-classifier"

# Temperature scaling (Guo et al. 2017). The model is *underconfident*: on the
# 215 PlantDoc field photos its mean top-1 probability was 0.60 even when it
# was right, so a correct answer routinely showed as "38%". Dividing the
# logits by T < 1 sharpens them without changing which class wins (accuracy
# and the top-3 list are untouched). T was fitted by NLL with 5-fold
# cross-validation and came out 0.56-0.58 on every fold; expected calibration
# error dropped from 0.197 to 0.056 and mean confidence on correct answers
# rose from 0.60 to 0.83. See notebooks/disease_calibration.json.
TEMPERATURE = 0.56

_temperature = TEMPERATURE  # replaced by a promoted retrained head's own T

_lock = threading.Lock()
_model = None
_processor = None


def _load():
    global _model, _processor
    if _model is not None:
        return _processor, _model
    with _lock:
        if _model is not None:  # re-check after acquiring the lock
            return _processor, _model
        processor = AutoImageProcessor.from_pretrained(_MODEL_REPO)
        model = AutoModelForImageClassification.from_pretrained(_MODEL_REPO)
        _apply_retrained_head(model)
        model.eval()
        _processor, _model = processor, model
        return _processor, _model


def _apply_retrained_head(model) -> None:
    """Swap in the classifier head that app/ml/disease/retrain.py promoted,
    if any. Only the final Linear(768 -> 28) layer is ever retrained; the ViT
    backbone stays exactly as published."""
    global _temperature
    path = get_settings().disease_head_path
    if not path.exists():
        return
    head = torch.load(path, map_location="cpu")
    model.classifier.weight.data.copy_(head["weight"])
    model.classifier.bias.data.copy_(head["bias"])
    _temperature = float(head["temperature"])
    logger.info("Using retrained disease head %s (%s)", path, head.get("metrics"))


def embed_and_logits(image: Image.Image) -> tuple[torch.Tensor, torch.Tensor]:
    """The 768-d feature the classifier head reads, and the raw logits —
    what retrain.py trains on."""
    processor, model = _load()
    inputs = processor(images=image.convert("RGB"), return_tensors="pt")
    with torch.no_grad():
        feat = model.vit(**inputs).last_hidden_state[:, 0]
        return feat[0], model.classifier(feat)[0]


def predict(image: Image.Image, top_k: int = 2) -> list[tuple[str, float]]:
    """Returns up to top_k (class_name, probability 0-1) pairs, sorted
    descending. Class names come from the model's own published id2label —
    no class-order assumptions anywhere."""
    processor, model = _load()
    inputs = processor(images=image.convert("RGB"), return_tensors="pt")
    with torch.no_grad():
        probs = torch.softmax(model(**inputs).logits / _temperature, dim=1)[0]
    k = min(top_k, probs.shape[0])
    top = torch.topk(probs, k)
    return [
        (model.config.id2label[int(i)], float(p))
        for p, i in zip(top.values.tolist(), top.indices.tolist())
    ]
