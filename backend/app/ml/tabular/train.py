"""Trains the two tabular models Phase 3 needs (docs/IMPLEMENTATION_PLAN.md
§5): crop recommendation and fertilizer recommendation. Both are
RandomForestClassifier on small tabular datasets — no GPU or deep learning
warranted (see the plan's §1 table: "RandomForest ... takes 4 seconds").

Run directly to (re)train both models and regenerate their evaluation report:

    cd backend
    .venv\\Scripts\\python -m app.ml.tabular.train

Data: backend/notebooks/data/{crop_recommendation,fertilizer_prediction}.csv
— see notebooks/data/SOURCES.md for provenance.

Outputs (all gitignored — regenerate with this script, don't hand-edit):
  app/ml/tabular/crop_rec.pkl          fitted sklearn Pipeline
  app/ml/tabular/fertilizer_rec.pkl    fitted sklearn Pipeline
  notebooks/crop_rec_report.json       metrics for the report
  notebooks/fertilizer_rec_report.json metrics for the report
"""
import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

_HERE = Path(__file__).resolve().parent
_BACKEND_DIR = _HERE.parents[2]
_DATA_DIR = _BACKEND_DIR / "notebooks" / "data"
_REPORT_DIR = _BACKEND_DIR / "notebooks"

RANDOM_STATE = 42

# Shared, human-readable feature names across both models (the source CSVs
# use inconsistent naming — N/P/K vs Nitrogen/Potassium/Phosphorous, a typo'd
# "Temparature", a trailing space in "Humidity " — cleaned up here, once,
# rather than leaking those inconsistencies into the API contract).
CROP_RENAME = {"N": "nitrogen", "P": "phosphorous", "K": "potassium"}
CROP_FEATURES = ["nitrogen", "phosphorous", "potassium", "temperature", "humidity", "ph", "rainfall"]

FERTILIZER_RENAME = {
    "Temparature": "temperature",
    "Humidity": "humidity",
    "Moisture": "moisture",
    "Soil Type": "soil_type",
    "Crop Type": "crop_type",
    "Nitrogen": "nitrogen",
    "Potassium": "potassium",
    "Phosphorous": "phosphorous",
    "Fertilizer Name": "fertilizer_name",
}
FERTILIZER_NUMERIC = ["temperature", "humidity", "moisture", "nitrogen", "potassium", "phosphorous"]
FERTILIZER_CATEGORICAL = ["soil_type", "crop_type"]


def _evaluate_and_save(pipeline: Pipeline, X: pd.DataFrame, y: pd.Series, name: str) -> None:
    """Honest held-out evaluation on an untouched split, then refit on the
    full dataset for the model that actually ships — the split exists only
    to measure generalization, never to shrink deployed training data."""
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=RANDOM_STATE
    )
    pipeline.fit(X_train, y_train)

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    cv_scores = cross_val_score(pipeline, X_train, y_train, cv=cv, scoring="accuracy")

    y_pred = pipeline.predict(X_test)
    labels = sorted(y.unique())
    report = {
        "n_samples": len(X),
        "n_classes": len(labels),
        "cv_accuracy_mean": round(float(cv_scores.mean()), 4),
        "cv_accuracy_std": round(float(cv_scores.std()), 4),
        "cv_fold_scores": [round(float(s), 4) for s in cv_scores],
        "test_accuracy": round(float((y_pred == y_test.to_numpy()).mean()), 4),
        "labels": labels,
        "confusion_matrix": confusion_matrix(y_test, y_pred, labels=labels).tolist(),
        "classification_report": classification_report(
            y_test, y_pred, labels=labels, output_dict=True, zero_division=0
        ),
    }

    pipeline.fit(X, y)  # refit on everything for the deployed model

    clf = pipeline.named_steps["clf"]
    try:
        feature_names = pipeline.named_steps["pre"].get_feature_names_out().tolist()
    except Exception:
        feature_names = [f"f{i}" for i in range(len(clf.feature_importances_))]
    report["feature_importances"] = sorted(
        (
            {"feature": f, "importance": round(float(i), 4)}
            for f, i in zip(feature_names, clf.feature_importances_)
        ),
        key=lambda x: -x["importance"],
    )

    _REPORT_DIR.mkdir(exist_ok=True)
    (_REPORT_DIR / f"{name}_report.json").write_text(json.dumps(report, indent=2))

    print(f"\n=== {name} ({report['n_samples']} rows, {report['n_classes']} classes) ===")
    print(f"5-fold CV accuracy: {report['cv_accuracy_mean']:.4f} +/- {report['cv_accuracy_std']:.4f}")
    print(f"Held-out test accuracy: {report['test_accuracy']:.4f}")
    print("Top features:", [f["feature"] for f in report["feature_importances"][:3]])


def train_crop_model() -> None:
    df = pd.read_csv(_DATA_DIR / "crop_recommendation.csv").rename(columns=CROP_RENAME)
    X, y = df[CROP_FEATURES], df["label"]

    pipeline = Pipeline([
        ("pre", ColumnTransformer([("num", "passthrough", CROP_FEATURES)])),
        ("clf", RandomForestClassifier(n_estimators=200, random_state=RANDOM_STATE)),
    ])
    _evaluate_and_save(pipeline, X, y, "crop_rec")
    joblib.dump(pipeline, _HERE / "crop_rec.pkl")


def train_fertilizer_model() -> None:
    df = pd.read_csv(_DATA_DIR / "fertilizer_prediction.csv")
    df.columns = [c.strip() for c in df.columns]  # source header has "Humidity " with a trailing space
    df = df.rename(columns=FERTILIZER_RENAME)
    features = FERTILIZER_NUMERIC + FERTILIZER_CATEGORICAL
    X, y = df[features], df["fertilizer_name"]

    pipeline = Pipeline([
        ("pre", ColumnTransformer([
            ("num", "passthrough", FERTILIZER_NUMERIC),
            ("cat", OneHotEncoder(handle_unknown="ignore"), FERTILIZER_CATEGORICAL),
        ])),
        ("clf", RandomForestClassifier(n_estimators=200, random_state=RANDOM_STATE)),
    ])
    _evaluate_and_save(pipeline, X, y, "fertilizer_rec")
    joblib.dump(pipeline, _HERE / "fertilizer_rec.pkl")


if __name__ == "__main__":
    train_crop_model()
    train_fertilizer_model()
