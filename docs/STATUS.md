# Implementation status

Tracks what's real vs. demo-only, against `docs/IMPLEMENTATION_PLAN.md`. Update
this file in the same commit as anything that moves a row between columns.

## Environment note

The Flutter SDK installed on this machine was 3.41.9 (Dart 3.11.5), but
`pubspec.yaml`/`pubspec.lock` require Flutter ≥3.44 (Dart ≥3.13.2) — the
project could not run `flutter pub get` at all before this pass. Fixed by
running `flutter upgrade` (free, official channel) to 3.47.5. If you're on a
different machine and hit the same "version solving failed" error, that's why.

## Phase 0 — Foundations: done

- `backend/` — FastAPI + SQLite, zero paid services, zero API keys.
  See `backend/README.md` for what's implemented and how to run it.
- `Farm` gained `latitude`/`longitude` (model, mock data, add/edit form) —
  every real data source needs them.
- Flutter `Farm` add/edit screen now actually persists (it didn't before —
  Save just closed the screen). Works in both demo mode (in-memory) and real
  mode (backend). Editing now also prefills the form (it didn't before).
- Delete on the farm list is wired up (it was a dead menu item before).
- Device-bound auth: the app has no login screen, so `POST /api/auth/register`
  is called once per install with a locally generated id; token is cached.
  See `backend/app/db/models.py` docstring for the reasoning.

## Phase 1 — Real data, no ML: in progress

| Screen | Status |
|---|---|
| Environment (current + history) | **Real** — Open-Meteo, when demo mode is off and the active farm has coordinates |
| Soil (current) | **Real** — SoilGrids (pH/texture baseline) + Open-Meteo (moisture). N/P/K are estimates, not lab values — see the module docstring in `backend/app/agronomy/soil_status.py` and the in-app soil insight that says so |
| Soil (history) | **Real** for Moisture/Temperature. pH history is not exposed (SoilGrids is a static baseline, not a daily series) — requesting it returns a clear error, not fabricated data |
| Soil insights | **Real** — derived client-side from the actual fetched SoilData in real mode; canned copy in demo mode |
| Environment alerts | **Not implemented in real mode** — this is the LangGraph agent's job (plan §3), not a plain GET. Real mode returns an empty list rather than fake alerts |
| Crop health / NDVI | **Demo only** — needs a Copernicus Data Space account (free, but requires signup) before the Sentinel connector can be built |
| Government schemes | **Demo only** — Phase 5 (RAG) |
| Notifications | **Demo only** — Phase 5 (daily agent worker) |
| Farmer profile | **Demo only** — not wired to the backend `User` row yet |

## Phase 2 — Disease detection: done (cascade stages [0],[1],[4] only)

- `POST /api/disease/detect` and `GET /api/disease/history` are real —
  `backend/app/ml/disease/`: quality gate (blur/brightness/size) → ViT
  classifier (`asafe51/plantdoc-disease-classifier`, free, downloaded from
  Hugging Face on first use, CPU-only) → honest decline when not confident
  (top-1 ≥ 40% AND margin over top-2 ≥ 20%, else "Uncertain — possible X"
  with a retake/KVK recommendation instead of a bare guess).

### The model was chosen by measurement, not by model card

Originally shipped `Daksh159/plant-disease-mobilenetv2` (PlantVillage-trained).
It was then evaluated properly on **215 real in-field photographs** (PlantDoc
test split) instead of the lab photos it was trained on, and it collapsed —
exactly the domain shift `docs/IMPLEMENTATION_PLAN.md` §1.1 predicts. Eight
candidates were measured on the identical test set:

| Model | Trained on | top-1 | top-3 |
|---|---|---|---|
| **asafe51/plantdoc-disease-classifier** (ViT) | PlantDoc (field) | **73.0%** | **94.4%** |
| aladinhabibi/vit-plantdoc | PlantDoc (field) | 43.7% | 78.1% |
| kimcomehome/plantvillage-vit-leaf-disease | PlantVillage (lab) | 40.0% | 70.2% |
| linkanjarad/mobilenet_v2 | PlantVillage (lab) | 32.6% | 55.3% |
| plantdoctor/swin-tiny (*card claims 99.83%*) | PlantVillage (lab) | 31.6% | 58.6% |
| AgUtkarsh007/efficientnet-b0-plantdoc | PlantDoc (field) | 24.2% | 35.8% |
| ~~Daksh159/plant-disease-mobilenetv2~~ (was shipped) | PlantVillage (lab) | 18.6% | 41.4% |
| A2H0H0R1/swin-tiny-plant-disease-new | PlantVillage (lab) | 3.7% | 4.7% |

Training **domain** mattered far more than architecture or advertised
accuracy. Several models advertising 95–99%+ score near 30% on real photos.

The old model was actively dangerous at its old gate: it answered
confidently on 51% of real photos and was **wrong about 3 times out of 4**
when it did (23.6% precision). The current model answers 62.3% of the time
at **88.8% precision**, and declines the rest.

Thresholds were calibrated from a measured sweep, not guessed — full sweep,
leakage analysis and limitations in `backend/notebooks/disease_field_eval.json`.
That file is the honest lab-vs-field table Phase 2's exit criteria asked for,
and is the thing worth putting in the report.
- Stages [2] (VLM second opinion) and [3] (paid API fallback / Kindwise) from
  the plan's §1.1 cascade are **not** wired up — both need API keys/spend
  this deployment doesn't have configured. See `backend/README.md` →
  "Disease detection model" for the extension point.
- Class labels now come straight from the model's own published `id2label`
  (28 classes, 13 crops) — there is no class-order guessing left anywhere,
  unlike the previous checkpoint whose ordering had to be reverse-engineered.
- **Coverage gap worth stating in the report:** no public checkpoint tested
  covers rice, wheat, cotton or sugarcane — four of India's biggest crops.
  The model handles tomato, potato, corn, grape, bell pepper, soybean,
  squash, apple, peach, cherry, strawberry, raspberry and blueberry.
- Blur threshold in `quality.py` was calibrated against real photos, not
  guessed — an initial default rejected a legitimate low-texture PlantVillage
  photo as "too blurry"; recalibrated with wide margin after measuring
  Laplacian variance on 5 sharp photos vs. the same photos heavily blurred.
- Eval set: **done** — 215 real field photos, with top-1/top-3/coverage/
  abstention measured for 8 candidate models. See the table above and
  `backend/notebooks/disease_field_eval.json`.
- Flutter: `diseaseDetectionProvider`/`diseaseHistoryProvider` in
  `lib/app/providers.dart` now call the real endpoints when demo mode is off,
  using the existing `ApiClient.uploadFile` multipart helper; demo mode is
  unchanged.

## Phase 3 — Tabular models: done

- Two `RandomForestClassifier` models trained from scratch on standard public
  datasets (`backend/app/ml/tabular/train.py`, see `notebooks/data/SOURCES.md`
  for provenance), each with a stratified train/test split, 5-fold CV,
  confusion matrix and feature importances saved for the report:
  - **Crop recommendation** — 2200 rows, 22 crops, 99.4% ±0.5% CV / 99.6% test
    accuracy. `POST /api/recommend/crop`.
  - **Fertilizer recommendation** — 99 rows, 7 fertilizers, 93.8% ±6.9% CV /
    100% test accuracy (small dataset, high CV variance — documented, not
    overstated). `POST /api/recommend/fertilizer`.
- Full metrics: `backend/notebooks/{crop_rec,fertilizer_rec}_report.json`.
- Flutter: new `lib/features/recommendation/` screens (two input forms +
  result cards), reachable from the dashboard's Quick Actions, wired to demo
  mode like every other screen.
- No pre-built UI existed for this feature (unlike disease detection) — both
  the models and the screens were built this phase.

## Phase 4 — The agent: done, scoped to 3 real specialists

- LangGraph agent (`backend/app/agent/`) behind `POST /api/advisory/ask` —
  ask a free-text question, get a sourced answer grounded in the farm's real
  data. Flutter: `lib/features/advisory/` chat screen ("Ask KrushiSarthi" on
  the dashboard).
- Graph: `weather` + `soil` + `disease` specialists run in parallel
  (deterministic — they call connectors/DB, no LLM) → `synthesis` → `writer`
  (the only 2 LLM calls per question) → deterministic `safety_gate` (keyword
  check for dosage/pesticide language, not an LLM call) → end. Every answer
  carries its `sources` (which tool, which value).
- **NDVI and market-price specialists are not built** — those connectors
  don't exist yet (Copernicus signup, Agmarknet), so the plan's full 5-domain
  graph is not implemented. Adding them later only needs new nodes in
  `agent/nodes.py` plus new `FarmState` fields — nothing else changes.
- New pure function `backend/app/agronomy/water_balance.py` (FAO-56
  irrigation math, ET0 × Kc − effective rainfall) — built this phase because
  the flagship question ("should I irrigate this week?") needs real
  arithmetic behind it, not an LLM guess. Not yet exposed as its own
  endpoint; only the agent's weather specialist calls it today.
- LLM: Groq (`openai/gpt-oss-120b`), via `GROQ_API_KEY` — the one required
  API key in this whole backend. My first default model guess
  (`llama-3.3-70b-versatile`) 404'd; Groq's free-tier lineup had moved on
  since my training data, corrected against the live `/models` list.
- Checkpointer: SQLite (`agent_checkpoints.db`, gitignored), not the plan's
  suggested Postgres — matches this project's zero-infrastructure pattern.
  Conversation state persists per (user, farm) but multi-turn follow-up isn't
  exposed from the Flutter side yet (each question is a fresh ask).
- No LangSmith tracing wired up (optional, env-var-only if added later).
- Verified end-to-end with real data via curl before touching the UI,
  including a safety-gate trigger on a pesticide-dosage question, where the
  LLM correctly declined to guess a dosage rather than confidently inventing
  one.

## How to actually see real data

1. `cd backend && python -m venv .venv && ...\.venv\Scripts\activate && pip install -r requirements.txt`
2. `uvicorn app.main:app --reload --port 8000`
3. Run the Flutter app (emulator default `10.0.2.2:8000` already matches).
4. Settings → turn off Demo Mode.
5. Farms → Add a farm → fill in Latitude/Longitude (e.g. `21.32`, `74.88` for
   Shirpur, Dhule — or long-press your own field on Google Maps to copy real
   coordinates) → Save.
6. Dashboard / Environment / Soil screens now hit the backend and show real
   weather + real modelled soil data for that exact location.

## Verified working (this pass)

Ran the backend directly with curl before touching the Flutter side:
register → create farm → `GET /api/environment/current?farm_id=...` → real
temperature/humidity for Shirpur, Dhule from Open-Meteo; `GET
/api/soil/current?farm_id=...` → real pH from SoilGrids + real moisture from
Open-Meteo. `flutter analyze` and `flutter test` both pass after the Flutter
changes.

## Next up (not started)

- Phase 1 remainder: NDVI via Copernicus (needs the user to create a free
  Copernicus Data Space account — can't be automated).
- Phase 2 remainder: cascade stages [2]/[3] (VLM second opinion, paid API
  fallback) once API keys exist — these would lift the ~27% of field photos
  the local model currently gets wrong. Optionally, fine-tuning on the
  PlantDoc *train* split would both raise accuracy and remove the residual
  (small) data-leakage uncertainty noted in `disease_field_eval.json`.
- Phase 4 remainder: NDVI/market specialists once their connectors exist;
  multi-turn follow-up questions from the Flutter chat (the checkpointer
  already persists state per farm, just not exposed yet); LangSmith tracing.
- Phase 5: daily automation worker (cron, 05:30 IST), FCM push notifications,
  voice (IndicConformer ASR + IndicTrans2), scheme RAG. Nothing here is
  "automated for farmers" yet — Phase 4 is real advice on request, not yet
  pushed without being asked.
