"""Stage [1] of the cascade — loads the local disease-classification CNN once
per process and exposes a thin `predict()`. Never trusted on its own; see
cascade.py for the confidence gate that wraps it.

Model: Daksh159/plant-disease-mobilenetv2 (Apache 2.0, Hugging Face) — a
torchvision MobileNetV2 with its classifier head replaced by
Sequential(Dropout(0.2), Linear(1280, 38)) and fine-tuned on the 38-class
PlantVillage dataset. Architecture, preprocessing and the class order in
labels.py were all verified empirically (strict state_dict load + 5/5 correct
predictions on labeled reference photos) before being trusted — see
labels.py's module docstring for details.
"""
import threading

import torch
from huggingface_hub import hf_hub_download
from PIL import Image
from torchvision import models, transforms

from app.ml.disease.labels import PLANT_DISEASE_CLASSES

_MODEL_REPO = "Daksh159/plant-disease-mobilenetv2"
_MODEL_FILE = "mobilenetv2_plant.pth"

_TRANSFORM = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])

_lock = threading.Lock()
_model: torch.nn.Module | None = None


def _load_model() -> torch.nn.Module:
    global _model
    if _model is not None:
        return _model
    with _lock:
        if _model is not None:  # re-check after acquiring the lock
            return _model
        weights_path = hf_hub_download(repo_id=_MODEL_REPO, filename=_MODEL_FILE)
        net = models.mobilenet_v2(weights=None)
        net.classifier[1] = torch.nn.Sequential(
            torch.nn.Dropout(0.2),
            torch.nn.Linear(net.last_channel, len(PLANT_DISEASE_CLASSES)),
        )
        state = torch.load(weights_path, map_location="cpu")
        net.load_state_dict(state, strict=True)
        net.eval()
        _model = net
        return _model


def predict(image: Image.Image, top_k: int = 2) -> list[tuple[str, float]]:
    """Returns up to top_k (class_name, probability 0-1) pairs, sorted descending."""
    net = _load_model()
    x = _TRANSFORM(image.convert("RGB")).unsqueeze(0)
    with torch.no_grad():
        probs = torch.softmax(net(x), dim=1)[0]
    top = torch.topk(probs, k=min(top_k, probs.shape[0]))
    return [
        (PLANT_DISEASE_CLASSES[i], float(p))
        for p, i in zip(top.values.tolist(), top.indices.tolist())
    ]
