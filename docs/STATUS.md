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
  `backend/app/ml/disease/`: quality gate (blur/brightness/size) → local
  MobileNetV2 CNN (`Daksh159/plant-disease-mobilenetv2`, Apache 2.0, free,
  downloaded from Hugging Face on first use, CPU-only) → honest decline when
  not confident (top-1 ≥ 85% AND margin over top-2 ≥ 20%, else "Uncertain —
  possible X" with a retake/KVK recommendation instead of a bare guess).
- Stages [2] (VLM second opinion) and [3] (paid API fallback / Kindwise) from
  the plan's §1.1 cascade are **not** wired up — both need API keys/spend
  this deployment doesn't have configured. See `backend/README.md` →
  "Disease detection model" for the extension point.
- The checkpoint's class-label order (38 PlantVillage classes) isn't sourced
  from the model card — its own README references a `class_names.json` that
  isn't actually in the HF repo. Used the standard PlantVillage alphabetical
  ordering instead and verified it empirically (strict state_dict load +
  5/5 correct predictions on labeled reference photos) before trusting it.
  See `backend/app/ml/disease/labels.py`'s docstring.
- Blur threshold in `quality.py` was calibrated against real photos, not
  guessed — an initial default rejected a legitimate low-texture PlantVillage
  photo as "too blurry"; recalibrated with wide margin after measuring
  Laplacian variance on 5 sharp photos vs. the same photos heavily blurred.
- No eval set yet (100–200 real field photos, top-1/top-3/abstention-rate
  table) — deferred; the plan's honest lab-vs-field accuracy-gap writeup for
  the report still needs that pass.
- Flutter: `diseaseDetectionProvider`/`diseaseHistoryProvider` in
  `lib/app/providers.dart` now call the real endpoints when demo mode is off,
  using the existing `ApiClient.uploadFile` multipart helper; demo mode is
  unchanged.

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
  Copernicus Data Space account — can't be automated) and the FAO-56
  irrigation water-balance calculation (`backend/app/agronomy/water_balance.py`
  doesn't exist yet, only `soil_status.py`).
- Phase 2 remainder: the eval set (100–200 real field photos, honest
  top-1/top-3/abstention table for the report) and, if useful, cascade
  stages [2]/[3] (VLM second opinion, paid API fallback) once API keys exist.
- Phase 3: the two trained tabular models (crop/fertilizer recommendation).
- Phase 4–5: the LangGraph agent and daily automation — nothing here is
  "automated for farmers" yet, it's real data on request.
