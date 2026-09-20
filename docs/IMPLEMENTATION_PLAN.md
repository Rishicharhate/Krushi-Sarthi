# KrushiSarthi — Implementation Plan

**Goal:** an automated crop & soil advisory system for Indian farmers. The farmer
registers a farm once; after that the system watches their field on its own and
pushes advice in their language, without them asking for it.

**Status today:** the Flutter app is a complete UI shell. Every screen exists,
every model class exists, `ApiConstants` already names the backend endpoints —
and every provider in `lib/app/providers.dart` returns `MockData`. Nothing behind
the UI is real. That is actually the ideal starting point: the contract is
already written, we just implement the other side of it.

---

## 1. The ML question, answered

The instinct "this needs many ML models and we can't train them" is half right.
It needs many *predictions*. It needs very few *trained models*. Sort every
feature into one of five buckets and the problem collapses:

| # | Feature | What actually produces the number | Training needed? |
|---|---------|-----------------------------------|------------------|
| 1 | NDVI / crop health | Band math on Sentinel-2 imagery: `(B08-B04)/(B08+B04)` | **None** — it is a formula |
| 2 | Weather / environment | Open-Meteo API (forecast + historical + ET₀) | **None** — it's NWP output |
| 3 | Soil baseline (pH, N, clay, SOC) | SoilGrids v2 REST API, 250 m global grid | **None** — pre-computed raster |
| 4 | Soil moisture | Open-Meteo soil moisture at 5 depths, or IoT sensor if you have one | **None** |
| 5 | Irrigation advice | FAO-56 Penman–Monteith water balance (ET₀ × Kc − rainfall) | **None** — agronomy equation |
| 6 | Pest / disease *risk forecast* | Growing-degree-day + leaf-wetness rule models from published agronomy | **None** — rules |
| 7 | Disease *detection from photo* | Pre-trained CNN/ViT from Hugging Face, + paid API fallback | **Download, don't train** |
| 8 | Voice input in Marathi/Hindi | AI4Bharat IndicConformer (MIT licence) | **Download, don't train** |
| 9 | Crop / fertilizer recommendation | RandomForest on a 2,200-row Kaggle dataset | **Yes — and it takes 4 seconds** |
| 10 | Yield estimate | Gradient boosting on district yield data, or NDVI-integral regression | **Yes — minutes on a laptop** |
| 11 | Scheme matching, explanations, chat | LLM + RAG over scheme documents | **None** |
| 12 | Market price trend | Agmarknet daily data + simple time-series | **None / trivial** |

Read the "training needed" column again. The only real training work is #9 and
#10, and those are tabular models on tiny datasets — `RandomForestClassifier` on
2,200 rows trains in under a second on a laptop CPU. "We can't train models"
is not a constraint here; it never applies to the things that actually need
training.

### 1.1 The one hard problem: disease detection accuracy

This is the feature that can genuinely embarrass you in a demo, so treat it
carefully.

Every "99% accurate plant disease model" you find on Hugging Face was trained on
**PlantVillage** — 54,000 leaves photographed *against a plain grey background in
a lab*. On a real photo taken by a farmer (soil, other leaves, shadow, wind
blur, half the leaf out of frame), reported accuracy falls off a cliff — field
benchmarks routinely show PlantVillage-trained models dropping from ~99% to
roughly 40–65%. This is a textbook domain-shift problem and is the single most
important thing to design around.

**Do not** ship a single model and trust its top-1 output. Ship a
confidence-gated cascade:

```
photo
  |
[0] quality gate       blur (Laplacian variance), brightness, is-there-a-leaf?
  |                    reject bad photos BEFORE inference, ask for a retake
[1] local model        MobileNetV2/EfficientNet from HF, served in FastAPI
  |                    accept if top-1 softmax >= 0.85 AND margin over top-2 >= 0.20
[2] VLM second opinion send image + candidate labels to a vision LLM,
  |                    ask it to confirm/deny citing visible evidence
[3] paid API fallback  Kindwise crop.health (~EUR 0.01-0.05/call), hard cases only;
  |                    a few hundred calls covers an entire demo season
[4] decline honestly   "Not confident. Nearest match X. Here's what to check,
                       and here's your KVK helpline."
```

Step [4] matters more than it looks. An advisory app that says "I'm not sure"
is trusted; one that confidently names the wrong disease and tells a farmer to
spray the wrong chemical is worse than no app at all. Show the confidence number
in the UI — `DiseaseResult` already carries a `confidence` field.

Candidate starting models (all free, all downloadable):
- `Diginsa/Plant-Disease-Detection-Project` — widely used baseline
- `Daksh159/plant-disease-mobilenetv2` — 38 classes, small, fast, mobile-friendly
- `liriope/PlantDiseaseDetection` — EfficientNetB4, ~97.7% on PlantVillage test

If you want one genuinely original ML contribution for the report, this is
where to put it: **fine-tune one of these on PlantDoc** (~2,600 real in-field
images) or on PlantVillage plus heavy augmentation (random background compositing,
motion blur, colour jitter), then report the honest lab-vs-field accuracy gap.
That is a far better contribution than another 99%-on-PlantVillage number, and it
trains on a free Colab T4 in well under an hour.

---

## 2. Architecture

```
+------------------------------------------------+
|  Flutter app (exists)                          |
|  Riverpod . Hive offline cache . demo mode     |
+---------------+--------------------------------+
                | REST - endpoints already in ApiConstants
+---------------v--------------------------------+
|  FastAPI backend                               |
|  auth . farms . CRUD . serves cached advisories|
+---+-----------------------+--------------------+
    |                       |
+---v--------------+   +----v---------------------------+
| Inference svc    |   | LangGraph agent service        |
| . disease CNN    |   | supervisor + specialist nodes  |
| . crop/fert RF   |   | tools = every connector below  |
| . ASR (Indic)    |   | Postgres checkpointer          |
+------------------+   +----+---------------------------+
                            |
      +---------------------+---------------------+
      |                     |                     |
+-----v------+  +-----------v-----+  +------------v-----+
| Open-Meteo |  | Copernicus /    |  | SoilGrids        |
| weather+ET0|  | Sentinel-2 NDVI |  | Agmarknet prices |
+------------+  +-----------------+  | scheme docs (RAG)|
                                     +------------------+
        +----------------------------------+
        | Postgres + PostGIS . Redis cache |
        +----------------------------------+
```

Keep the inference service and the agent service as separate processes. The CNN
holds a few hundred MB of weights resident; you do not want that coupled to the
agent's restart cycle, and you want to scale them independently.

### 2.1 Backend repo layout

```
backend/
  app/
    main.py                 FastAPI entrypoint
    api/                    routers, one per ApiConstants group
      auth.py farms.py soil.py environment.py crop.py disease.py
      schemes.py notifications.py profile.py advisory.py
    core/                   config, security, deps
    db/                     SQLAlchemy models, migrations (alembic)
    connectors/             one module per external source, each cached + retried
      open_meteo.py sentinel.py soilgrids.py agmarknet.py
    agronomy/               pure functions, unit-tested, no I/O
      et0.py water_balance.py gdd.py ndvi.py nutrient.py
    ml/
      disease/  loader.py cascade.py quality.py
      tabular/  crop_rec.pkl fertilizer.pkl train.py
      asr/      indic_conformer.py
    agent/
      state.py graph.py nodes/ tools/ prompts/
    workers/
      daily_advisory.py     the cron that makes it "automated"
  tests/
  notebooks/                training + evaluation, for the report
```

---

## 3. The agentic layer (LangGraph)

This is what turns a dashboard into "automated for farmers". The distinction
that matters: **the farmer should not have to open the app to get advice.** A
cron job runs the graph per farm each morning; the graph decides whether
anything is worth saying; if it is, it writes a notification the app already
knows how to render (`NotificationItem`, `notifications_screen.dart`).

### 3.1 State

Define this before writing a single node. LangGraph's type checking is strict
about schema changes once checkpoints are persisted, and refactoring state after
a dozen nodes exist is painful.

```python
class FarmState(TypedDict):
    farm_id: str
    farm: FarmContext              # crop, sowing_date, area, lat/lon, soil_type
    language: str                  # 'mr' | 'hi' | 'en'
    trigger: str                   # 'daily_cron' | 'user_question' | 'photo_upload'
    user_message: str | None

    weather: WeatherBundle | None  # filled by specialist nodes
    soil: SoilBundle | None
    ndvi: NdviBundle | None
    disease: DiseaseBundle | None
    market: MarketBundle | None

    findings: Annotated[list[Finding], operator.add]   # parallel-safe accumulator
    advisories: list[Advisory]
    needs_human: bool
    messages: Annotated[list[AnyMessage], add_messages]
```

`findings` uses an additive reducer so specialist nodes can fan out in parallel
and merge without clobbering each other.

### 3.2 Graph

```
                    +--------------+
     entry ------->|  supervisor  |<----------+
                    +------+-------+           |
         +---------+-------+--------+----------+
         v         v       v        v          |
    +--------++--------++------++-------++---------+
    |weather || soil   || ndvi ||disease|| market  |  <- run in parallel
    | agent  || agent  ||agent || agent || agent   |
    +----+---++---+----++--+---++---+---++----+----+
         +--------+--------+--------+---------+
                           v
                  +------------------+
                  |  risk synthesis  |  correlate findings across domains
                  +--------+---------+
                           v
                  +------------------+
                  | advisory writer  |  rank, dedupe, write in farmer's language
                  +--------+---------+
                           v
                  +------------------+      high-stakes? (pesticide dose,
                  |  safety gate     |----> "uproot the crop") -> needs_human
                  +--------+---------+      or attach a verified source
                           v
                       notify / respond
```

The supervisor pattern is worth its complexity here precisely because we need
the three things LangGraph actually exists for: persistence across sessions,
parallel fan-out with state merging, and human approval gates.

### 3.3 Tools

Every tool is a thin, typed, cached wrapper — the agent never calls an HTTP API
directly:

| Tool | Backed by | Cache TTL |
|------|-----------|-----------|
| `get_weather_forecast(lat, lon, days)` | Open-Meteo | 3 h |
| `get_et0_and_rainfall(lat, lon, range)` | Open-Meteo | 6 h |
| `get_soil_profile(lat, lon)` | SoilGrids v2 | 30 days (static) |
| `get_soil_moisture(lat, lon)` | Open-Meteo / IoT | 1 h |
| `get_ndvi_series(geometry, range)` | Sentinel-2 | until next overpass (~5 d) |
| `detect_disease(image_id)` | local cascade | permanent per image |
| `recommend_crop(n,p,k,ph,temp,humidity,rain)` | RandomForest | — |
| `compute_irrigation_need(farm_id)` | `agronomy/water_balance.py` | 6 h |
| `get_mandi_prices(commodity, state)` | Agmarknet / data.gov.in | 12 h |
| `search_schemes(profile)` | RAG over scheme corpus | 7 d |
| `get_crop_calendar(crop, sowing_date)` | static table | — |

Two rules that keep this trustworthy:

1. **Agronomy math lives in Python, not in the LLM.** The model decides *what to
   look at* and *how to say it*. It never computes ET₀ or NDVI in its head. LLMs
   are unreliable at arithmetic and you cannot defend a hallucinated irrigation
   depth in a viva.
2. **Every advisory carries its provenance** — which tool, which value, which
   threshold fired. Store it; show it on tap. This doubles as your debugging tool.

### 3.4 What "automated" looks like, concretely

`workers/daily_advisory.py`, run at 05:30 IST per farm:

1. Refresh weather, soil moisture, and — if a new Sentinel pass landed — NDVI.
2. Run the graph with `trigger='daily_cron'`.
3. Specialists emit findings: *"NDVI dropped 0.11 in 10 days in the NE quadrant"*,
   *"soil moisture 14%, ET₀ 5.2 mm/d, no rain for 6 days"*, *"3 consecutive days
   above 85% RH at 25–30 °C — late blight infection window open"*.
4. Synthesis correlates them — falling NDVI **plus** a blight window **plus** the
   crop being tomato is a very different message from falling NDVI alone.
5. Writer produces at most 3 ranked advisories in Marathi/Hindi, each with an
   action, a deadline, and a reason.
6. Push notification to the app. The farmer opens it to a screen that already exists.

That loop, running without the farmer touching anything, *is* the project.

---

## 4. Data sources (all verified, with limits)

| Source | Gives | Cost / limit |
|--------|-------|--------------|
| [Open-Meteo](https://open-meteo.com/) | forecast, historical, soil moisture at 5 depths, **ET₀ reference evapotranspiration** | free, no API key, 10k calls/day non-commercial |
| [Copernicus Data Space](https://dataspace.copernicus.eu/) | Sentinel-2 L2A → NDVI, NDWI, NDRE | free account, 10,000 Processing Units/month; an NDVI request is roughly 34 PU, so about 290 requests/month. Cache hard. |
| [SoilGrids v2](https://rest.isric.org/) | pH, N, SOC, clay/sand/silt, CEC at 6 depths | free; **fair use = 5 calls/min** → cache permanently per location |
| [data.gov.in Agmarknet](https://www.data.gov.in/catalog/current-daily-price-various-commodities-various-markets-mandi) | daily mandi min/max/modal prices, 6,000+ markets | free API key |
| [AI4Bharat IndicConformer](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) | ASR for 22 Indian languages incl. Marathi, Hindi | free, MIT |
| AI4Bharat IndicTrans2 | translation for advisory text | free |
| Hugging Face PlantVillage models | disease classification | free |
| [Kindwise crop.health](https://www.kindwise.com/crop-health) | high-accuracy crop disease API | from ~EUR 0.05/credit, cheaper in volume — fallback only |

**The Sentinel PU budget is your real constraint.** ~290 NDVI requests/month is
plenty for 20 demo farms refreshed once per 5-day overpass, and nowhere near
enough to refresh on every screen open. Cache NDVI per (geometry, date) in
Postgres and never fetch the same thing twice.

---

## 5. Phased roadmap

Each phase ends with something demonstrable. Do not build the agent first — it
has nothing to reason over until the connectors exist.

### Phase 0 — Foundations (week 1)
- FastAPI skeleton with every route in `ApiConstants` returning the *same JSON
  shape the Dart models already parse*. Hardcode the responses at first.
- Postgres + PostGIS, Alembic, Docker Compose.
- Switch the Flutter providers to hit the API when demo mode is off; keep
  `MockData` as the demo-mode path. Add `latitude`/`longitude` to `Farm` — every
  external data source is geospatial and the model currently has no coordinates.
- **Exit:** the app runs against a real (if boring) backend, demo mode still works.

### Phase 1 — Real data, no ML (weeks 2–3)
- `connectors/open_meteo.py` → environment screens show real weather.
- `connectors/soilgrids.py` → soil screen shows a real profile for the farm's
  location. Label it honestly: a modelled estimate at 250 m, not a sensor reading.
- `connectors/sentinel.py` → real NDVI plus history; crop health screen goes live.
- `agronomy/` pure functions with unit tests: ET₀, per-crop Kc curves, water
  balance, growing degree days.
- **Exit:** 3 of the 4 dashboard cards show real numbers for a real field. This is
  already a working product and a defensible demo.

### Phase 2 — Disease detection (week 4)
- Serve an HF model behind `/api/disease/detect`, wire up the existing upload UI.
- Build the full cascade from §1.1: quality gate → local → VLM → paid → decline.
- Build a small honest eval set: 100–200 real field photos (your own plus PlantDoc),
  and report top-1, top-3, and the abstention rate. **Put this table in the report.**
- **Exit:** photo in, calibrated diagnosis out, with a confidence you can defend.

### Phase 3 — Tabular models (week 5, about 2 days)
- Train the crop recommendation and fertilizer models. Stratified split, 5-fold
  cross-validation, confusion matrix, feature importances. Export as pickle or ONNX.
- Serve behind `/api/recommend/crop` and `/api/recommend/fertilizer`.
- **Exit:** two models you trained yourself, with real evaluation, for the report.

### Phase 4 — The agent (weeks 6–7)
- `FarmState`, tool wrappers, supervisor plus 5 specialists, Postgres checkpointer.
- LangSmith tracing from day one — you cannot debug a 12-node graph from logs.
- Risk synthesis, advisory writer, safety gate.
- **Exit:** ask "should I irrigate this week?" and get a sourced, correct answer.

### Phase 5 — Automation + language (weeks 8–9)
- `daily_advisory.py` on APScheduler or Celery beat, per farm, 05:30 IST.
- FCM push into the existing notifications screen.
- IndicConformer ASR endpoint and a mic button; IndicTrans2 for output. A farmer
  asking a question by voice in Marathi and hearing the answer back is the single
  highest-impact feature in this whole plan for the actual end user.
- Scheme RAG: collect scheme PDFs, chunk, embed, retrieve, match against
  `FarmerProfile`. The schemes screens already exist.
- **Exit:** the app advises without being asked, in the farmer's language.

### Phase 6 — Hardening + report (week 10)
- Offline-first: Hive is already wired; make sure the last advisory survives a
  total loss of connectivity. Farmers in fields have bad signal — this is not
  polish, it is core.
- Rate limiting, cost caps on the paid fallback, real error surfaces.
- Evaluation chapter: model metrics, agent trace examples, honest limitations.

---

## 6. Decisions to make now

1. **IoT sensors — in scope or not?** If you have (or can borrow) a soil NPK and
   moisture sensor plus an ESP32, add an MQTT ingest path and the soil screen
   becomes genuinely measured rather than modelled. If not, SoilGrids plus
   Open-Meteo is a perfectly defensible software-only path — just label estimates
   as estimates. Everything else in this plan is unaffected either way.
2. **LLM budget.** The agent needs an LLM. Plan for a few hundred rupees of API
   spend across the semester, or run a small local model for the writer node and
   keep a hosted model for synthesis only.
3. **Languages at launch.** Recommended: Marathi and English first, Hindi next.
4. **Hosting.** A Render/Railway free tier is enough for the API; the CNN wants
   roughly 1 GB RAM, so either a small paid instance or a Hugging Face Space
   dedicated to inference.

## 7. Risks

| Risk | Mitigation |
|------|-----------|
| Field-photo accuracy collapse | The cascade in §1.1 plus honest abstention. Never a bare top-1. |
| Sentinel PU exhaustion mid-demo | Hard caching; pre-warm demo farms the night before. |
| Cloud cover hides the field for 2 weeks | Show data age prominently; fall back to the last clear pass and say so. |
| Agent hallucinating agronomy | All math in Python; provenance on every advisory; safety gate on dosages. |
| Scope explosion | Phases 0–2 alone are a complete, defensible project. Everything after is upside. |

## 8. Next three actions

1. Add `latitude` / `longitude` to `Farm` (model, form, mock data) — nothing
   geospatial works without it.
2. Scaffold `backend/` and make `/api/environment/current` return real
   Open-Meteo data in the exact shape `EnvironmentData.fromJson` expects.
3. Point the Flutter environment providers at it behind the existing demo-mode
   flag. One screen, end to end, real. Then repeat the pattern nine more times.
