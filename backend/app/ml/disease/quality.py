"""Stage [0] of the confidence-gated cascade in docs/IMPLEMENTATION_PLAN.md
§1.1 — reject unusable photos before spending inference time on them, and ask
for a retake instead of guessing on a bad picture. Heuristic thresholds, not
learned; tune against real submissions once real usage data exists.
"""
import numpy as np
from PIL import Image, ImageFilter

MIN_DIMENSION = 128
# Calibrated against 5 real PlantVillage reference photos (sharp: 54-2160) vs.
# the same photos with a heavy Gaussian blur applied (all < 1) — see the git
# history of this file for the calibration script. 20 sits with wide margin
# below every real sharp sample and well above every blurred one.
MIN_LAPLACIAN_VARIANCE = 20.0
MIN_MEAN_BRIGHTNESS = 25.0     # below this, too dark to make out leaf detail
MAX_MEAN_BRIGHTNESS = 235.0    # above this, blown-out / overexposed

# Discrete 3x3 Laplacian — a standard, dependency-light blur estimator
# (the variance of the Laplacian response drops sharply for out-of-focus images).
_LAPLACIAN_KERNEL = ImageFilter.Kernel((3, 3), [0, 1, 0, 1, -4, 1, 0, 1, 0], scale=1)


class QualityRejected(Exception):
    """Raised when a photo fails the quality gate. Message is farmer-facing."""


def check(image: Image.Image) -> None:
    width, height = image.size
    if width < MIN_DIMENSION or height < MIN_DIMENSION:
        raise QualityRejected("Image is too small. Please retake at a higher resolution.")

    gray = image.convert("L")
    brightness = float(np.asarray(gray, dtype=np.float64).mean())
    if brightness < MIN_MEAN_BRIGHTNESS:
        raise QualityRejected("Photo is too dark to analyze. Retake in better light.")
    if brightness > MAX_MEAN_BRIGHTNESS:
        raise QualityRejected("Photo is overexposed. Retake out of direct glare.")

    edges = gray.filter(_LAPLACIAN_KERNEL)
    # Pillow's Kernel filter treats out-of-image neighbors as black, which
    # inflates the response along the outer 2px border regardless of actual
    # sharpness (confirmed empirically: a perfectly flat image scores ~134
    # instead of 0 until that border is excluded). Crop it out before scoring.
    edge_array = np.asarray(edges, dtype=np.float64)[2:-2, 2:-2]
    variance = float(edge_array.var()) if edge_array.size else 0.0
    if variance < MIN_LAPLACIAN_VARIANCE:
        raise QualityRejected("Photo looks blurry. Hold the camera steady and refocus on the leaf.")
