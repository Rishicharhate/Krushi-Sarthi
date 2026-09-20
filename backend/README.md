# KrushiSarthi backend

FastAPI service backing the Flutter app. Every endpoint implemented so far is
free to run: SQLite (a file, no server), two external APIs that need no key —
[Open-Meteo](https://open-meteo.com/) (weather, ET₀, soil moisture) and
[SoilGrids v2](https://rest.isric.org/) (ISRIC — global soil baseline) — and a
local, free (Apache 2.0) disease-classification model that runs on CPU, no
API key or GPU required. See `docs/IMPLEMENTATION_PLAN.md` at the repo root
for the full roadmap; this covers Phase 0, the start of Phase 1, and Phase 2.

## What's real right now

| Endpoint | Backed by | Notes |
|---|---|---|
| `POST /api/auth/register` | local DB | device-bound token, no password (see `app/db/models.py` docstring) |
| `GET/POST/PUT/DELETE /api/farms` | local DB | per-user CRUD |
| `GET /api/environment/current` | Open-Meteo | temperature, humidity, rainfall, wind |
| `GET /api/environment/history` | Open-Meteo archive | daily temperature/humidity, last N days |
| `GET /api/soil/current` | SoilGrids + Open-Meteo | pH/texture baseline + live moisture; N/P/K are **estimates**, not lab values — see `app/agronomy/soil_status.py` |
| `GET /api/soil/history` | Open-Meteo archive | moisture and temperature only; pH has no free daily source and is intentionally not exposed here |
| `POST /api/disease/detect` | local MobileNetV2 cascade | quality gate → CNN → honest decline, see `app/ml/disease/`. VLM/paid-API cascade stages from the plan's §1.1 are not wired up (need API keys this deployment doesn't have) |
| `GET /api/disease/history` | local DB | per-user scan history, newest first |

Everything else in `ApiConstants` on the Flutter side (crop health/NDVI,
schemes, notifications, profile) is still demo-mode-only — not implemented
here yet. That's Phases 3–5 in the plan.

## Run it

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env      # defaults already work, edit if you want
uvicorn app.main:app --reload --port 8000
```

Visit `http://127.0.0.1:8000/docs` for interactive Swagger docs.

The Android emulator reaches your host machine at `10.0.2.2` — that's already
the default `API_BASE_URL` in `lib/core/constants/api_constants.dart`, so a
Flutter build talking to `localhost:8000` on your machine needs no config
change. A physical device needs your machine's LAN IP instead; pass it at
build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

## Data model note

`Farm.latitude` / `Farm.longitude` are required for every endpoint above —
weather, soil and (later) satellite data are all geospatial. A farm without
coordinates gets a clear 400 error telling the caller to set them, not a
silently wrong answer.

## Why SQLite, not Postgres

The plan document sketches Postgres + PostGIS for later, but nothing built so
far needs geospatial queries (we just store two floats), and SQLite means
zero infrastructure to install or pay for while the project is still growing.
Swap `DATABASE_URL` in `.env` when that stops being true — the SQLAlchemy
layer doesn't care.

## Caching and rate limits

SoilGrids' fair-use policy is roughly 5 calls/minute; Open-Meteo's free tier
caps at 10,000 calls/day. Every connector in `app/connectors/` caches its
result in the `api_cache` table (`app/db/cache.py`) before either limit
becomes a problem — soil data for 30 days (it's a static raster), weather for
3 hours. Don't remove the caching to "get fresher data"; it exists to keep
this free.

## Tests

None yet. `app/agronomy/` is pure functions by design specifically so it's
cheap to unit test — that's the first thing worth adding.

## Disease detection model

`POST /api/disease/detect` downloads `Daksh159/plant-disease-mobilenetv2`
(Apache 2.0, ~9 MB) from Hugging Face on first use and caches it under the
`huggingface_hub` cache directory — no manual download step, no API key.
CPU-only PyTorch wheels (see the `--extra-index-url` line in
`requirements.txt`); no GPU required.

That checkpoint's own README references a `class_names.json` that isn't
actually in the repo, so the 38-class label order in `app/ml/disease/labels.py`
is the standard PlantVillage alphabetical ordering, not something sourced
from the model card — it was verified before being trusted (strict
`state_dict` load + 5/5 correct top-1 predictions on labeled reference photos
from a public PlantVillage mirror). See that file's docstring for details.

The cascade (`app/ml/disease/cascade.py`) only implements stages [0], [1] and
[4] of the plan's §1.1 confidence-gated pipeline — quality gate, local model,
honest decline. Stages [2] (VLM second opinion) and [3] (paid API fallback,
e.g. Kindwise crop.health) are not wired up; both need API keys/spend this
deployment isn't configured with. Add them inside `run_cascade`'s
`if is_confident` branch when ready.
