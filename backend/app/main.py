from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.agent.graph import init_agent, shutdown_agent
from app.api import (
    advisory, auth, crop, disease, environment, farms, market, notifications,
    recommend, schemes, soil,
)
from app.core.config import get_settings
from app.db.database import init_db
from app.workers.daily_advisory import run_daily_advisory_for_all_farms

settings = get_settings()

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serves uploaded disease-detection photos back out (see app/api/disease.py).
_STATIC_DIR = settings.static_dir
_STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=_STATIC_DIR), name="static")


@app.on_event("startup")
def _startup() -> None:
    init_db()


@app.on_event("startup")
async def _startup_agent() -> None:
    # Opens the LangGraph checkpointer's SQLite connection for the process
    # lifetime (see app/agent/graph.py). Cheap even without GROQ_API_KEY set
    # — the key is only required when POST /api/advisory/ask actually runs.
    await init_agent()


@app.on_event("shutdown")
async def _shutdown_agent() -> None:
    await shutdown_agent()


# Phase 5 automation (docs/IMPLEMENTATION_PLAN.md §5) — runs the daily
# advisory worker for every farm at 05:30 IST. See
# app/workers/daily_advisory.py and POST /api/notifications/run-daily for a
# way to trigger it on demand instead of waiting for the schedule.
_scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")


@app.on_event("startup")
def _startup_scheduler() -> None:
    _scheduler.add_job(
        run_daily_advisory_for_all_farms,
        CronTrigger(hour=5, minute=30),
        id="daily_advisory",
        replace_existing=True,
    )
    _scheduler.start()


@app.on_event("shutdown")
def _shutdown_scheduler() -> None:
    _scheduler.shutdown(wait=False)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(farms.router, prefix=settings.api_v1_prefix)
app.include_router(environment.router, prefix=settings.api_v1_prefix)
app.include_router(soil.router, prefix=settings.api_v1_prefix)
app.include_router(disease.router, prefix=settings.api_v1_prefix)
app.include_router(recommend.router, prefix=settings.api_v1_prefix)
app.include_router(advisory.router, prefix=settings.api_v1_prefix)
app.include_router(schemes.router, prefix=settings.api_v1_prefix)
app.include_router(notifications.router, prefix=settings.api_v1_prefix)
app.include_router(crop.router, prefix=settings.api_v1_prefix)
app.include_router(market.router, prefix=settings.api_v1_prefix)
