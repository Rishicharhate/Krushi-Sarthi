"""Scheme corpus + semantic search — Phase 5's "Scheme RAG"
(docs/IMPLEMENTATION_PLAN.md §5). The corpus is a small, hand-curated set of
real government schemes (app/data/schemes.json, sourced in
app/data/SCHEMES_SOURCES.md), not a scraped PDF pipeline — see that file for
why. Each scheme is one retrieval chunk (already short and atomic); the
embed/retrieve mechanics here don't change if the corpus grows or starts
covering multi-paragraph PDFs later, only the chunking step would.

Everything is computed once per process and cached in memory — 7 short
documents is nowhere near needing a real vector database.
"""
import json
import threading
from pathlib import Path

import numpy as np

from app.rag.embeddings import get_model

_CORPUS_PATH = Path(__file__).resolve().parents[1] / "data" / "schemes.json"

_lock = threading.Lock()
_schemes: list[dict] | None = None
_embeddings: np.ndarray | None = None


def _scheme_text(scheme: dict) -> str:
    """What actually gets embedded — the fields a farmer's query is likely
    to semantically match against."""
    return " ".join([
        scheme["name"],
        scheme["description"],
        scheme["eligibility"],
        scheme["benefits"],
    ])


def _load() -> tuple[list[dict], np.ndarray]:
    global _schemes, _embeddings
    if _schemes is not None:
        return _schemes, _embeddings
    with _lock:
        if _schemes is not None:  # re-check after acquiring the lock
            return _schemes, _embeddings
        schemes = json.loads(_CORPUS_PATH.read_text(encoding="utf-8"))
        model = get_model()
        texts = [_scheme_text(s) for s in schemes]
        embeddings = model.encode(texts, normalize_embeddings=True, convert_to_numpy=True)
        _schemes, _embeddings = schemes, embeddings
        return _schemes, _embeddings


def list_schemes() -> list[dict]:
    schemes, _ = _load()
    return schemes


def get_scheme(scheme_id: str) -> dict | None:
    schemes, _ = _load()
    return next((s for s in schemes if s["id"] == scheme_id), None)


def search_schemes(query: str, top_k: int = 5) -> list[tuple[dict, float]]:
    """Semantic search — matches on meaning, not just keyword overlap (e.g.
    "money if my crop gets destroyed by rain" should surface PMFBY crop
    insurance even without a single shared word). Cosine similarity over
    normalized embeddings, computed via a plain dot product since both sides
    are already unit-normalized."""
    schemes, embeddings = _load()
    model = get_model()
    query_vec = model.encode([query], normalize_embeddings=True, convert_to_numpy=True)[0]
    scores = embeddings @ query_vec
    ranked_idx = np.argsort(-scores)[:top_k]
    return [(schemes[i], float(scores[i])) for i in ranked_idx]
