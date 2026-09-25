# KrushiSarthi backend

FastAPI service backing the Flutter app. Free to run except for one piece:
the advisory agent (Phase 4) needs a Groq API key (free tier). Everything
else — SQLite, [Open-Meteo](https://open-meteo.com/), [SoilGrids v2](https://rest.isric.org/),
the local disease-classification model, the local tabular models, and local
scheme-search embeddings — needs zero API keys. See `docs/IMPLEMENTATION_PLAN.md`
at the repo root for the full roadmap and `docs/STATUS.md` for a
phase-by-phase account of what was actually built vs. what the plan sketched.

## What's real right now

| Endpoint | Backed by | Notes |
|---|---|---|
| `POST /api/auth/register` | local DB | device-bound token, no password (see `app/db/models.py` docstring) |
| `GET/POST/PUT/DELETE /api/farms` | local DB | per-user CRUD |
| `GET /api/environment/current` | Open-Meteo | temperature, humidity, rainfall, wind |
| `GET /api/environment/history` | Open-Meteo archive | daily temperature/humidity, last N days |
| `GET /api/soil/current` | SoilGrids + Open-Meteo | pH/texture baseline + live moisture; N/P/K are **estimates**, not lab values — see `app/agronomy/soil_status.py` |
| `GET /api/soil/history` | Open-Meteo archive | moisture and temperature only; pH has no free daily source and is intentionally not exposed here |
| `POST /api/disease/detect` | local ViT cascade | quality gate → CNN → honest decline, see `app/ml/disease/` and "Disease detection model" below. VLM/paid-API cascade stages are not wired up (need API keys this deployment doesn't have) |
| `GET /api/disease/history` | local DB | per-user scan history, newest first |
| `POST /api/recommend/crop` | local RandomForest | trained on 2200 rows, 22 crops, 99.6% test accuracy — see `app/ml/tabular/` |
| `POST /api/recommend/fertilizer` | local RandomForest | trained on 99 rows, 7 fertilizers — see `app/ml/tabular/` |
| `POST /api/advisory/ask` | LangGraph agent (Groq LLM) | all 5 specialists (weather, soil, disease, NDVI, market) + FAO-56 irrigation math, sourced answers — see `app/agent/`. **Needs `GROQ_API_KEY`** |
| `GET /api/schemes`, `GET /api/schemes/{id}` | local corpus | 7 real central government schemes — see `app/data/` |
| `GET /api/schemes/search` | local embeddings | semantic search, not keyword match — see `app/rag/` |
| `GET /api/notifications` | local DB | written by the daily automation worker |
| `GET /api/crop/health`, `GET /api/crop/ndvi/history` | Sentinel-2 (AWS Open Data) | real cloud-masked NDVI, **no account or API key** — see "Sentinel-2 NDVI" below |
| `GET /api/market/prices` | Agmarknet (data.gov.in) | real daily mandi prices — see "Mandi prices" below |
| `POST /api/notifications/run-daily` | local DB + agent tools | manually runs today's check now, instead of waiting for the 05:30 IST cron — see `app/workers/daily_advisory.py` |

Not yet implemented: farmer profile sync, FCM push, voice. Demo-mode-only
on the Flutter side for now.

## Sentinel-2 NDVI — no Copernicus account needed

The plan routes NDVI through Copernicus Data Space, which needs a
free-but-registered account and a Processing Unit budget. There is a second
route with neither: Sentinel-2 L2A is mirrored on **AWS Open Data**,
searchable via the public Earth Search STAC API and readable anonymously over
HTTP range requests. Cloud-Optimized GeoTIFFs mean a windowed read around one
farm fetches a few KB, not the 100MB+ full band.

**Cloud masking is mandatory here, not a nicety.** Every reading is masked
with the scene classification (SCL) band and rejected if fewer than 40% of
the field's pixels are genuinely clear — the endpoint then 404s with a plain
"no cloud-free view" message rather than returning an NDVI that is really
measuring cloud shadow. Over an Indian monsoon that can be the honest answer
for weeks. See `app/connectors/sentinel.py`.

## Mandi prices

`app/connectors/agmarknet.py`. Two things that cost real debugging time and
are documented in that file so they don't have to be rediscovered:

  * data.gov.in **silently stalls** requests carrying httpx's default
    `python-httpx/...` User-Agent — the connection just hangs until timeout
    with no error explaining why. An honest client identifier gets an
    instant 200.
  * Commodity names are Agmarknet's own vocabulary, not what farmers type:
    `Soybean` matches 0 records, `Soyabean` matches 162. `COMMODITY_ALIASES`
    maps the app's crop names onto the real ones, each verified against the
    live API.

The default API key is the sample key from data.gov.in's own docs, which
caps responses at 10 records. Register a free personal key and set
`DATA_GOV_API_KEY` to lift that.

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

## Deploying to Render

`render.yaml` at the repo root is a Render Blueprint for this backend.

1. On render.com: **New → Blueprint**, then pick this GitHub repo.
2. Render asks for `GROQ_API_KEY` and `DATA_GOV_API_KEY`. Paste them there,
   not into any committed file. It generates `JWT_SECRET` itself.
3. The first build installs CPU torch and takes roughly 10 minutes. The first
   disease scan and scheme search after that download their models
   (~450 MB) to the disk, so they are slow once.
4. Build the app against the deployed URL:
   `flutter build apk --dart-define=API_BASE_URL=https://krushisarthi-api.onrender.com`

The plan has to be **Standard (2 GB)**. The loaded ML models need ~950 MB,
which is over the 512 MB of Free and Starter. A free instance would also
sleep, so the 05:30 cron would never run, and it can't attach a disk. The
SQLite DB, the agent checkpoints and uploaded photos all live on the
`/var/data` disk (`DATABASE_URL`, `AGENT_CHECKPOINT_DB` and `STATIC_DIR`), so
they survive redeploys.

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

`POST /api/disease/detect` downloads `asafe51/plantdoc-disease-classifier`
from Hugging Face on first use and caches it under the `huggingface_hub`
cache directory — no manual download step, no API key. CPU-only PyTorch
wheels (see the `--extra-index-url` line in `requirements.txt`); no GPU
required.

**This model was picked by measurement, not by its model card.** On 215 real
in-field photographs it scores 73.0% top-1 / 94.4% top-3. The
PlantVillage-trained checkpoint originally shipped here scored 18.6% on the
same photos despite excellent lab-test numbers — the domain-shift problem
`docs/IMPLEMENTATION_PLAN.md` §1.1 warns about, measured rather than assumed.
Several other candidates advertising 95–99%+ accuracy scored around 30%.

Full comparison of 8 candidates, the confidence-threshold sweep behind
`cascade.py`'s numbers, a data-leakage analysis and honest limitations:
`notebooks/disease_field_eval.json`. If you swap the model, re-run that
evaluation on field photos — lab accuracy will mislead you.

The cascade (`app/ml/disease/cascade.py`) only implements stages [0], [1] and
[4] of the plan's §1.1 confidence-gated pipeline — quality gate, local model,
honest decline. Stages [2] (VLM second opinion) and [3] (paid API fallback,
e.g. Kindwise crop.health) are not wired up; both need API keys/spend this
deployment isn't configured with. Add them inside `run_cascade`'s
`if is_confident` branch when ready.

## Advisory agent (Phase 4)

`POST /api/advisory/ask` is the only endpoint in this backend that needs a
paid-capable API key — Groq, via `GROQ_API_KEY` in `.env` (free tier
available at console.groq.com). Everything else needs zero keys.

The graph (`app/agent/graph.py`) runs weather/soil/disease specialists in
parallel (deterministic, no LLM — they just call `app/agent/tools.py`), then
two LLM calls (synthesis, writer), then a deterministic keyword safety gate.
NDVI and market-price specialists from the plan aren't included — those
connectors don't exist. A SQLite checkpointer (`agent_checkpoints.db`,
gitignored) persists conversation state per (user, farm).

If `GROQ_MODEL` 404s, Groq's free-tier model lineup has moved on — list what's
currently available:
```bash
.venv\Scripts\python -c "from groq import Groq; from app.core.config import get_settings; [print(m.id) for m in Groq(api_key=get_settings().groq_api_key).models.list().data]"
```

## Daily automation worker (Phase 5)

`app/workers/daily_advisory.py` runs at 05:30 IST (APScheduler, wired in
`app/main.py`) across every farm with coordinates set, reusing the same
specialist tools the interactive agent uses. It only writes a notification
when something crosses a real threshold — most days, nothing fires, on
purpose. `POST /api/notifications/run-daily` runs it immediately for the
caller's own farms, so the automation is demonstrable without waiting for
the schedule.

## Scheme RAG (Phase 5)

`app/rag/` — 7 real central government schemes (`app/data/schemes.json`,
sourced in `app/data/SCHEMES_SOURCES.md`), embedded locally with
`sentence-transformers/all-MiniLM-L6-v2` (free, CPU, no API key). No vector
database — brute-force cosine similarity over 7 vectors is fast enough.
`GET /api/schemes/search?q=...` does genuine semantic retrieval: a query
like "money if rain destroys my harvest" surfaces crop insurance (PMFBY)
with zero shared keywords. It isn't always ranked #1 (small model, tiny
corpus) — see `docs/STATUS.md` for the honest result, not an inflated one.

## Disease model: calibration, retraining and tester feedback

Measured numbers are in `notebooks/disease_calibration.json`.

- **Calibration.** The published model was underconfident: a correct
  diagnosis averaged 60% confidence. Temperature scaling fixes the displayed
  percentage without changing which disease wins. Correct answers now
  average about 84%. The cascade thresholds (`cascade.py`) are set on this
  calibrated scale.
- **Retrained final layer (`disease_head.pt`).** Retraining only the last
  layer on PlantDoc's training photos, with balanced classes, raised
  PlantDoc test accuracy from 72.5% to 78.0%. The loader uses this file
  whenever it exists.
- **Tester feedback (testing phase only).** With `FEEDBACK_MODE=true` in a
  local `.env`, the app asks "was this correct?" after every scan. If the
  answer is no, the tester types or picks the real disease. Production
  (`render.yaml`) keeps `FEEDBACK_MODE=false`, so farmers are never asked.
  To learn from the collected answers:

  ```bash
  python -m app.ml.disease.retrain            # dry run: prints metrics
  python -m app.ml.disease.retrain --promote  # writes disease_head.pt
  ```

  Feedback is used only when it beats the plain retrain on the tester's own
  photos (cross-validated). Nothing is promoted if accuracy on the held-out
  PlantDoc test photos drops. This is supervised learning from human labels.
  It is not RLHF, which trains a reward model to steer an LLM's text.
  Spider mites is the main gap to fill: PlantDoc has only 2 training photos
  of it.
