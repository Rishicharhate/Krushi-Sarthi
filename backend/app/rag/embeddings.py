"""Lazily loads a small, free, local sentence-embedding model. No API key —
runs on CPU, ~90MB download from Hugging Face on first use, cached after.
"""
import threading

from sentence_transformers import SentenceTransformer

_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

_lock = threading.Lock()
_model: SentenceTransformer | None = None


def get_model() -> SentenceTransformer:
    global _model
    if _model is not None:
        return _model
    with _lock:
        if _model is not None:  # re-check after acquiring the lock
            return _model
        _model = SentenceTransformer(_MODEL_NAME)
        return _model
