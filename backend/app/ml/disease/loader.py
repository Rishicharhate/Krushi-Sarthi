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
import threading

import torch
from PIL import Image
from transformers import AutoImageProcessor, AutoModelForImageClassification

_MODEL_REPO = "asafe51/plantdoc-disease-classifier"

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
        model.eval()
        _processor, _model = processor, model
        return _processor, _model


def predict(image: Image.Image, top_k: int = 2) -> list[tuple[str, float]]:
    """Returns up to top_k (class_name, probability 0-1) pairs, sorted
    descending. Class names come from the model's own published id2label —
    no class-order assumptions anywhere."""
    processor, model = _load()
    inputs = processor(images=image.convert("RGB"), return_tensors="pt")
    with torch.no_grad():
        probs = torch.softmax(model(**inputs).logits, dim=1)[0]
    k = min(top_k, probs.shape[0])
    top = torch.topk(probs, k)
    return [
        (model.config.id2label[int(i)], float(p))
        for p, i in zip(top.values.tolist(), top.indices.tolist())
    ]
