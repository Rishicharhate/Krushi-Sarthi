# Dataset sources

Both files in this directory are copies of standard, widely-used public
datasets (originally published on Kaggle), fetched via the GitHub mirror
[`Suryam-2023/Crop-and-Fertilizer-Recommendation-System`](https://github.com/Suryam-2023/Crop-and-Fertilizer-Recommendation-System)
since Kaggle itself requires an account/API key to download programmatically.
Cite the original Kaggle listings in the report, not the GitHub mirror.

## `crop_recommendation.csv`

- **2200 rows, 22 balanced crop classes** (100 rows each).
- Columns: `N`, `P`, `K` (soil nutrient ratios, kg/ha equivalents), `temperature`
  (°C), `humidity` (%), `ph`, `rainfall` (mm) → `label` (crop name).
- Originally: Atharva Ingle, "Crop Recommendation Dataset", Kaggle.

## `fertilizer_prediction.csv`

- **99 rows, 7 fertilizer classes** (Urea, DAP, 14-35-14, 28-28, 17-17-17,
  20-20, 10-26-26) — small; document this honestly in the report rather than
  overstating the model's reliability.
- Columns: `Temparature` [sic, source typo], `Humidity ` [sic, trailing
  space in the source header], `Moisture`, `Soil Type`, `Crop Type`,
  `Nitrogen`, `Potassium`, `Phosphorous` → `Fertilizer Name`.
- Originally: Gaurav "Aksha" (gdabhishek), "Fertilizer Prediction", Kaggle.
- `train.py` renames every column to clean snake_case on load — the typos
  above only exist in this raw CSV, never downstream.
