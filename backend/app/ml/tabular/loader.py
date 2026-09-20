"""Lazily loads the two trained pipelines from train.py (see that file's
docstring for how to regenerate crop_rec.pkl / fertilizer_rec.pkl)."""
import threading
from pathlib import Path

import joblib
import pandas as pd

_HERE = Path(__file__).resolve().parent

_lock = threading.Lock()
_crop_model = None
_fertilizer_model = None


def _load(path: Path):
    if not path.exists():
        raise FileNotFoundError(
            f"{path.name} not found. Train it first: "
            f"cd backend && .venv\\Scripts\\python -m app.ml.tabular.train"
        )
    return joblib.load(path)


def _top_predictions(model, row: dict, top_k: int) -> list[tuple[str, float]]:
    df = pd.DataFrame([row])
    probs = model.predict_proba(df)[0]
    ranked = sorted(zip(model.classes_, probs), key=lambda pair: -pair[1])
    return [(str(label), float(prob)) for label, prob in ranked[:top_k]]


def predict_crop(row: dict, top_k: int = 3) -> list[tuple[str, float]]:
    global _crop_model
    if _crop_model is None:
        with _lock:
            if _crop_model is None:
                _crop_model = _load(_HERE / "crop_rec.pkl")
    return _top_predictions(_crop_model, row, top_k)


def predict_fertilizer(row: dict, top_k: int = 3) -> list[tuple[str, float]]:
    global _fertilizer_model
    if _fertilizer_model is None:
        with _lock:
            if _fertilizer_model is None:
                _fertilizer_model = _load(_HERE / "fertilizer_rec.pkl")
    return _top_predictions(_fertilizer_model, row, top_k)
