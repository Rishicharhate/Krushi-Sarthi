from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.agent.graph import init_agent, shutdown_agent
from app.api import advisory, auth, disease, environment, farms, recommend, soil
from app.core.config import get_settings
from app.db.database import init_db

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
_STATIC_DIR = Path(__file__).resolve().parent / "static"
_STATIC_DIR.mkdir(exist_ok=True)
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
