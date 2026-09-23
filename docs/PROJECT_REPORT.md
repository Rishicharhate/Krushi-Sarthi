# KrushiSarthi — Project Report

**An automated crop & soil advisory system for Indian farmers**

Flutter (Android / Web) + FastAPI backend
Repository: `Rishicharhate/Krushi-Sarthi`

---

## 1. Overview

KrushiSarthi watches a farmer's field on its own and pushes advice in plain
language, rather than requiring the farmer to interpret raw data. The farmer
registers a farm once (with coordinates); after that the system pulls live
weather, soil, satellite and market data for that exact location, runs
agronomy calculations and ML models over it, and produces sourced
recommendations.

The defining constraint throughout was **honesty over impressiveness**: at
every point where the system could have shown a confident-looking number that
wasn't actually trustworthy, it was built to say "I don't know" instead. This
turned out to be the single most important design decision, and is documented
with measurements below.

**Cost profile:** the entire system runs on free services. Exactly one
component (the LLM agent) needs an API key, and that has a free tier.

---

## 2. Architecture

```
+----------------------------------------------+
| Flutter app (Android + Web)                   |
| Riverpod state . demo mode / real mode toggle |
+-------------------+--------------------------+
                    | REST
+-------------------v--------------------------+
| FastAPI backend (SQLite, device-bound auth)   |
+-----------------------------------------------+
| connectors/   open_meteo, soilgrids,          |
|               sentinel, agmarknet             |
| agronomy/     soil_status, water_balance      |
| ml/disease/   quality -> ViT -> honest decline|
| ml/tabular/   crop_rec.pkl, fertilizer_rec.pkl|
| rag/          scheme corpus + embeddings      |
| agent/        LangGraph, 5 specialists        |
| workers/      daily_advisory (05:30 IST cron) |
+-----------------------------------------------+
```

### Key architectural decisions and why

| Decision | Rationale |
|---|---|
| SQLite, not Postgres/PostGIS | Nothing needs geospatial queries (we store two floats). Zero infrastructure cost. Swap `DATABASE_URL` later; the SQLAlchemy layer doesn't care. |
| Device-bound auth, no login screen | The app had no sign-in UI. `POST /api/auth/register` once per install with a locally generated ID. Smallest thing that makes data private-per-install without forcing login into scope. |
| `schemas.py` **is** the contract | Pydantic field names match the Dart `fromJson` methods exactly. Changing one without the other is the bug class this prevents. |
| Agronomy math in Python, never in the LLM | You cannot defend a hallucinated irrigation depth in a viva. The LLM decides *what to look at* and *how to say it*; it never computes ET0. |
| Demo mode preserved throughout | Every screen works offline with mock data. Real mode is a toggle, not a rewrite. |

---

## 3. Data sources (all free, all verified live)

| Source | Provides | Auth | Cache |
|---|---|---|---|
| Open-Meteo | Temperature, humidity, rainfall, wind, ET0, soil moisture (5 depths) | None | 3 h |
| SoilGrids v2 (ISRIC) | pH, nitrogen, organic carbon, clay/sand/silt | None | 30 days |
| Sentinel-2 L2A (AWS Open Data) | 10 m NDVI via STAC + Cloud-Optimized GeoTIFFs | **None** | Per scene, permanent |
| Agmarknet (data.gov.in) | Daily mandi min/max/modal prices, 6000+ markets | Free API key | 12 h |
| Hugging Face | Disease classifier (ViT), embedding model | None | Local |
| Groq | LLM for the advisory agent | Free-tier key | — |

---

## 4. Machine learning components & evaluation

### 4.1 Disease detection — the most important result in the project

**The problem.** Nearly every public "99% accurate plant disease model" is
trained on **PlantVillage** — 54,000 leaves photographed against a plain grey
background in a lab. A farmer's camera produces something completely
different: soil, other leaves, shadow, wind blur, half the leaf out of frame.
This is textbook domain shift.

**What was done.** Rather than trust any model card, a real test set was
built — **215 genuine in-field photographs** from the PlantDoc test split (27
classes) — and **8 candidate models were measured on identical images**:

| Model | Trained on | top-1 | top-3 |
|---|---|---|---|
| **asafe51/plantdoc-disease-classifier** (ViT) | PlantDoc (field) | **73.0%** | **94.4%** |
| aladinhabibi/vit-plantdoc | PlantDoc (field) | 43.7% | 78.1% |
| kimcomehome/plantvillage-vit | PlantVillage (lab) | 40.0% | 70.2% |
| linkanjarad/mobilenet_v2 | PlantVillage (lab) | 32.6% | 55.3% |
| plantdoctor/swin-tiny *(card claims 99.83%)* | PlantVillage (lab) | 31.6% | 58.6% |
| AgUtkarsh007/efficientnet-b0-plantdoc | PlantDoc (field) | 24.2% | 35.8% |
| ~~Daksh159/mobilenetv2~~ *(originally shipped)* | PlantVillage (lab) | **18.6%** | 41.4% |
| A2H0H0R1/swin-tiny | PlantVillage (lab) | 3.7% | 4.7% |

**Findings worth stating in a viva:**

1. **Training domain dominated architecture and marketing claims.** One model
   advertising **99.83% accuracy** scored **31.6%** on real photos.
2. **The originally-shipped model was actively dangerous** — at its confidence
   gate it answered on 51% of real photos and was **wrong roughly 3 times out
   of 4** when it did (23.6% precision). A confidently wrong diagnosis that
   sends a farmer to spray the wrong chemical is worse than no app at all.
3. Replacing it improved field top-1 from **18.6% -> 73.0%**, a ~4x
   improvement.

**Confidence gate calibration** (measured sweep, not guessed):

| Confidence | Margin | Coverage | Precision when answering |
|---|---|---|---|
| 0.30 | 0.10 | 78.1% | 82.7% |
| **0.40** | **0.20** | **62.3%** | **88.8%**  <- chosen |
| 0.50 | 0.20 | 51.6% | 91.0% |
| 0.85 | 0.20 | 10.2% | 100% |

0.40/0.20 was chosen deliberately: a wrong diagnosis is costly, so precision
is worth more than coverage, and declining isn't a dead end — the system
still returns the nearest match plus what to check and a KVK helpline
referral.

**Data-leakage check.** The selected model's model card is empty, so its
train/test split can't be verified. Evidence against leakage: mean top-1
probability is only **0.534** overall (0.598 even when correct), and only
**1.9%** of images exceed p > 0.95. A model that had memorised these test
images would cluster near 1.0. Also, 73% sits in the normal published range
for PlantDoc benchmarks (~70%), not the suspicious 95–100% a leaked split
produces.

**Quality gate (stage 0).** Rejects unusable photos *before* inference:
minimum dimension, mean brightness 25–235, and blur via Laplacian variance.
Two calibration bugs were found and fixed by measurement:

- Pillow's kernel filter zero-pads at image borders, inflating variance — a
  perfectly flat image scored 134 instead of 0. Fixed by excluding the 2 px
  border.
- An initial threshold of 80 falsely rejected a legitimate low-texture photo.
  Recalibrated to 20 after measuring 5 sharp photos (54–2160) against the same
  photos heavily blurred (all < 1).

**Honest limitations:** 73% top-1 means roughly 1 in 4 raw predictions is
wrong — which is exactly why the gate and decline stage exist. The model
covers 28 classes across 13 crops, and **no public checkpoint tested covers
rice, wheat, cotton or sugarcane** — four of India's largest crops.

Full comparison, threshold sweep, leakage analysis and limitations:
`backend/notebooks/disease_field_eval.json`.

### 4.2 Crop & fertilizer recommendation (trained from scratch)

Two `RandomForestClassifier` models, both with stratified split, 5-fold
cross-validation, confusion matrix and feature importances:

| Model | Data | Classes | 5-fold CV | Held-out test |
|---|---|---|---|---|
| Crop recommendation | 2,200 rows | 22 crops | **99.4% ± 0.5%** | **99.6%** |
| Fertilizer recommendation | 99 rows | 7 fertilizers | **93.8% ± 6.9%** | 100% |

Top features — crop: rainfall, humidity, potassium. Fertilizer: phosphorous,
nitrogen, potassium.

**Stated honestly:** the fertilizer model's 99-row dataset produces high
cross-validation variance (±6.9%), and its 100% test accuracy reflects a tiny
test split, not genuine perfection. This is documented rather than presented
as a headline number.

Full metrics: `backend/notebooks/{crop_rec,fertilizer_rec}_report.json`.
Dataset provenance: `backend/notebooks/data/SOURCES.md`.

### 4.3 NDVI — satellite crop health

**A significant correction was made here.** The project plan routed NDVI
through Copernicus Data Space, which requires a registered account and
consumes a Processing Unit budget, and this was initially recorded as a
blocker. That was wrong. Sentinel-2 L2A is also mirrored on **AWS Open
Data**, searchable via the public Earth Search STAC API and readable
**anonymously** over HTTP range requests — no account, no API key, no PU
budget.

Because the imagery is stored as Cloud-Optimized GeoTIFFs, a windowed read of
a ~210 m box around one farm fetches a few KB instead of the 100 MB+ full
band.

**Cloud masking is mandatory, and this produced the most interesting
technical finding.** Over the test farm (Shirpur, monsoon season) *every*
scene in a 6-week window was 52–100% cloud, and the first reading attempted
was measuring **cloud shadow**, not crop. Every reading is now masked with the
scene-classification (SCL) band and discarded if under 40% of the field's
pixels are genuinely clear.

> **Key finding:** scene-wide cloud percentage is a *bad* predictor for a
> specific small field. The usable pass over Shirpur was a **73%-cloud
> scene** (the field sat in a gap), while a **52%-cloud scene** had the field
> under shadow. Ranking candidate scenes by scene-wide cloud and truncating
> *silently dropped the only good reading*, turning a real NDVI into a false
> "no clear view". Checking the cheap SCL band for every candidate is what
> makes the result deterministic.

Verified result: **NDVI 0.824 ("Healthy")** from the 2026-09-15 pass.

**Performance engineering:** cold fetch ~10–30 s, warm **0.008 s**. Achieved
via per-scene permanent caching (a past satellite pass never changes), a
two-phase read (cheap SCL band for all candidates, expensive spectral bands
only for the few that matter), bounded concurrency, and a per-scene timeout.
A sentinel value distinguishes *"the read timed out"* from *"this scene
genuinely doesn't see the field"* — conflating them would permanently cache a
transient network failure as "cloudy".

---

## 5. The advisory agent (LangGraph)

```
START --+--> weather  --+
        +--> soil       |
        +--> disease    +--> synthesis --> writer --> safety_gate --> END
        +--> ndvi       |     (LLM)        (LLM)    (deterministic)
        +--> market   --+
```

All five specialists run **in parallel** and are **deterministic** — they call
connectors and the database, with no LLM involved. Their findings merge
through an additive reducer. Only two LLM calls happen per question
(synthesis and writer), keeping cost and latency bounded.

**The safety gate is deliberately not an LLM call.** It's a keyword scan for
chemical-dosage and destructive-action language (`pesticide`, `dosage`, `ppm`,
`ml/l`, `uproot`...). A dosage recommendation shouldn't depend on whether an
LLM happened to flag its own output.

**Every answer carries provenance** — which tool, which value, which source —
displayed on tap.

### Verified behaviours

- *"Should I irrigate this week?"* -> correct sourced answer citing a 14.9 mm
  deficit computed from FAO-56 water balance (ET0 x Kc − effective rainfall),
  soil moisture 63%, and a concrete action.
- *"What pesticide and dosage should I spray?"* -> safety gate fired
  (`needs_human: true`), **and** the model correctly declined to invent a
  dosage because no pest data existed, recommending the farmer scout and
  identify the pest first.
- *"How is my crop doing, and is it a good time to sell?"* -> correlated NDVI
  0.82 + soil + irrigation deficit + live mandi prices into a single
  recommendation.

### A real bug caught by testing

The first market-enabled answer told a **Maharashtra** farmer to sell at a
**Tamil Nadu** mandi ~1500 km away, because Agmarknet returns nationwide
prices. The market finding now states which states the mandis span and
explicitly instructs the model not to treat a distant high price as
reachable. Re-tested: it correctly said the Rs 11,000 price "is from distant
Tamil Nadu mandis and isn't a realistic option for you."

---

## 6. Automation & scheme retrieval

**Daily advisory worker** — APScheduler, 05:30 IST, across every farm with
coordinates. Reuses the *same* specialist tools as the interactive agent, so
the daily check and the chat never disagree about what "real data" means. The
LLM is explicitly told that an empty result is the normal, expected answer
most days; it only writes a notification when a finding crosses a real
threshold. *Verified:* on a live test farm it wrote exactly **one**
notification (an irrigation deficit) rather than padding to three.

A manual trigger (`POST /api/notifications/run-daily`) exists so the
automation is demonstrable on demand rather than only at 5:30 the next
morning.

**Scheme RAG** — 7 real central government schemes (PM-KISAN, PMFBY, Kisan
Credit Card, Soil Health Card, e-NAM, PMKSY, RKVY), embedded locally with
`all-MiniLM-L6-v2`. No vector database — brute-force cosine similarity over 7
vectors is more than fast enough, and adding one would be unjustified
complexity.

*Verified genuine semantic retrieval:* the query **"money if rain destroys my
harvest"** surfaces PMFBY crop insurance in the top 3 **with zero shared
keywords**. Reported honestly: it isn't always rank-1, which is realistic for
a 22 M-parameter model on a 7-item corpus.

Scheme content was sourced from Wikipedia because the official portals
(pmkisan.gov.in, pmfby.gov.in, myscheme.gov.in) are JavaScript-rendered
single-page apps that serve no fetchable static content. Every
`application_url` still points at the **real government portal**, not
Wikipedia. Figures that drift (premium rates, subsidy percentages) explicitly
tell the farmer to confirm on the official portal. Provenance:
`backend/app/data/SCHEMES_SOURCES.md`.

---

## 7. Notable engineering findings

These cost real debugging time and are documented in code so they don't have
to be rediscovered:

1. **data.gov.in silently stalls `python-httpx`.** Requests with the default
   `python-httpx/...` User-Agent hang until timeout with *no error explaining
   why*. An honest client identifier gets an instant 200. Diagnosed by testing
   User-Agents against the live API.
2. **Agmarknet uses its own commodity vocabulary.** `Soybean` matches **0**
   records; `Soyabean` matches **162**. A verified alias map now translates
   the app's crop names.
3. **Flutter Web's Dio adapter bounds the whole request by `connectTimeout`,**
   not just the handshake — so a `receiveTimeout` alone is silently ignored on
   web. This caused spurious "connection timeout" errors on slow satellite and
   soil calls.
4. **SoilGrids is genuinely slow** (10–20 s measured), and the client timeout
   was tighter than the server's own upstream timeout — the app gave up before
   the backend could answer.
5. **Groq's model lineup changes.** The initial default
   (`llama-3.3-70b-versatile`) returned 404; corrected to
   `openai/gpt-oss-120b` after querying the live model list.

---

## 8. Honest limitations

- **Soil N/P/K are estimates, not measurements.** SoilGrids publishes nitrogen
  but not phosphorus or potassium at useful resolution — no free global source
  does. P and K are coarse pedotransfer-style estimates from organic carbon
  and texture. The app says so in-app and points farmers at the free
  government Soil Health Card test.
- **pH has no daily history.** SoilGrids is a static survey baseline, so
  requesting a pH time series returns a clear explanation rather than a
  fabricated trend.
- **Disease detection covers 28 classes / 13 crops**, excluding rice, wheat,
  cotton and sugarcane.
- **~27% of field photos are still misclassified** at raw top-1; the
  confidence gate exists precisely because of this.
- **Mandi prices are nationwide, not filtered to the farmer's state.** The
  agent is instructed to account for this; proper filtering needs the farmer
  profile wired to the backend user record.
- **Cloud cover can hide a field for weeks.** The system reports this honestly
  instead of showing a stale or cloud-contaminated NDVI.
- **The fertilizer model's dataset is only 99 rows.**

---

## 9. Not yet built

| Item | Blocker |
|---|---|
| FCM push notifications | Needs a Firebase project (account setup) |
| Voice (IndicConformer ASR + IndicTrans2) | Large models; needs Flutter mic/audio wiring |
| Farmer profile <-> backend sync | Not started |
| VLM second opinion + paid API fallback (disease cascade stages 2–3) | Needs API keys/spend |
| Multi-turn chat follow-ups | Checkpointer already persists state; just not exposed in UI |

---

## 10. Technology stack

- **Frontend:** Flutter 3.47.5, Riverpod, GoRouter, Dio, fl_chart, image_picker
- **Backend:** FastAPI, SQLAlchemy/SQLite, Pydantic, httpx, APScheduler
- **ML:** PyTorch (CPU), Transformers (ViT), scikit-learn (RandomForest),
  sentence-transformers, rasterio/GDAL
- **Agent:** LangGraph, LangChain, Groq (`openai/gpt-oss-120b`)

---

## 11. Summary

The strongest theme for the report and viva is this: **at four separate
points, an assumption was tested and turned out to be wrong**, and measuring
rather than assuming changed the outcome materially.

1. A disease model advertising excellent accuracy scored **18.6%** on real
   photos — replaced with one scoring **73%**.
2. NDVI was recorded as blocked on an account signup — it wasn't; an anonymous
   route existed.
3. Ranking satellite scenes by cloud cover *seemed* sensible but **silently
   discarded the only usable reading**.
4. A market-aware agent confidently recommended a mandi 1500 km away.

None of these would have been caught by trusting documentation, model cards,
or plausible-sounding heuristics. That is a genuinely defensible
contribution, and more interesting than another "99% accuracy on
PlantVillage" claim.

---

*See also:* `docs/IMPLEMENTATION_PLAN.md` (original roadmap and design
rationale) and `docs/STATUS.md` (phase-by-phase account of what was actually
built versus what the plan sketched).
