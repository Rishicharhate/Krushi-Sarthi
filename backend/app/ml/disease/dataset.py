"""The labelled disease-photo dataset built from tester feedback.

Layout is the standard ImageFolder one — one folder per class, named with
the model's own label — so any training tool (torchvision, Keras, a Colab
notebook) can read it as-is, and photos from other sources can be dropped
into the matching folder:

    datasets/disease_feedback/
        Tomato two spotted spider mites leaf/<scan_id>.jpg
        Tomato Septoria leaf spot/<scan_id>.jpg
        _not_in_list/<scan_id>.jpg + <scan_id>.txt   (tester's description)

Written live by POST /api/disease/feedback, read by retrain.py.

    python -m app.ml.disease.dataset             # per-class counts
    python -m app.ml.disease.dataset --rebuild   # re-file every feedback row
"""
import argparse
import shutil
from pathlib import Path

from app.core.config import get_settings
from app.ml.disease.labels import DISEASE_INFO

NOT_IN_LIST = "_not_in_list"
_IMAGE_EXTS = {".jpg", ".jpeg", ".png"}


def _root() -> Path:
    return get_settings().disease_dataset_dir


def save(scan_id: str, image: Path, label: str | None, note: str | None) -> Path:
    """File one scan's photo under its label. Re-answering moves it: any
    earlier copy of this scan in another folder is removed first."""
    root = _root()
    for old in root.glob(f"*/{scan_id}.*"):
        old.unlink()
    folder = root / (label or NOT_IN_LIST)
    folder.mkdir(parents=True, exist_ok=True)
    dest = folder / f"{scan_id}{image.suffix.lower()}"
    shutil.copy2(image, dest)
    if label is None and note:
        (folder / f"{scan_id}.txt").write_text(note, encoding="utf-8")
    return dest


def labelled_images() -> list[tuple[Path, str]]:
    """(photo, label) for every image in a known-class folder. Folders whose
    name isn't a model label (typos, _not_in_list) are ignored."""
    root = _root()
    if not root.exists():
        return []
    return [
        (p, folder.name)
        for folder in sorted(root.iterdir())
        if folder.is_dir() and folder.name in DISEASE_INFO
        for p in sorted(folder.iterdir())
        if p.suffix.lower() in _IMAGE_EXTS
    ]


def counts() -> dict[str, int]:
    root = _root()
    if not root.exists():
        return {}
    return {
        f.name: sum(1 for p in f.iterdir() if p.suffix.lower() in _IMAGE_EXTS)
        for f in sorted(root.iterdir()) if f.is_dir()
    }


def rebuild() -> int:
    """Re-file every feedback row from the database — for photos submitted
    before the dataset existed, or after deleting the folder."""
    from app.db.database import SessionLocal, init_db
    from app.db.models import DiseaseFeedback, DiseaseScan

    init_db()
    upload_dir = get_settings().static_dir / "uploads" / "disease"
    n = 0
    with SessionLocal() as db:
        rows = db.query(DiseaseFeedback, DiseaseScan).join(DiseaseScan, DiseaseScan.id == DiseaseFeedback.scan_id)
        for fb, scan in rows:
            src = upload_dir / scan.image_path
            if src.exists():
                save(scan.id, src, fb.true_label, fb.note)
                n += 1
    return n


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Labelled disease-photo dataset")
    ap.add_argument("--rebuild", action="store_true")
    args = ap.parse_args()
    if args.rebuild:
        print(f"filed {rebuild()} photos")
    print(f"{_root()}")
    for label, n in counts().items():
        print(f"  {n:>4}  {label}")
