"""Application settings.

Every default here keeps the project free to run: SQLite needs no server,
Open-Meteo and SoilGrids need no API key. Nothing in this file requires a
credit card. Override via a local .env file (see .env.example) or real
environment variables — never hardcode secrets in code.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "KrushiSarthi API"
    api_v1_prefix: str = "/api"

    # SQLite by default — a single file, zero infrastructure cost.
    # Point DATABASE_URL at Postgres later if/when the project needs it.
    database_url: str = "sqlite:///./krushisarthi.db"

    # Secret used to sign the app's own JWTs (device-bound auth — see
    # app/core/security.py). Generate a real one for anything beyond local dev:
    #   python -c "import secrets; print(secrets.token_urlsafe(48))"
    jwt_secret: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = 60 * 24 * 30  # 30 days — this is a device token, not a session

    # Allow the Flutter app (emulator / device / web) to call this API during dev.
    cors_origins: list[str] = ["*"]

    # Open-Meteo — free, no API key, non-commercial cap of 10k calls/day.
    open_meteo_forecast_url: str = "https://api.open-meteo.com/v1/forecast"
    open_meteo_archive_url: str = "https://archive-api.open-meteo.com/v1/archive"

    # SoilGrids v2 (ISRIC) — free, no API key, fair-use ~5 calls/minute.
    # Results are cached hard (see connectors/soilgrids.py) because of that limit.
    soilgrids_url: str = "https://rest.isric.org/soilgrids/v2.0/properties/query"

    # Sentinel-2 NDVI via the AWS Open Data mirror + Earth Search STAC —
    # free, and notably **no account or API key**, unlike the Copernicus Data
    # Space route the plan sketches. See connectors/sentinel.py.
    stac_search_url: str = "https://earth-search.aws.element84.com/v1/search"

    # data.gov.in (Agmarknet mandi prices). The default below is the sample
    # key published in data.gov.in's own API docs — shared by everyone using
    # those docs and revocable, so register a free personal key and set
    # DATA_GOV_API_KEY in .env for anything beyond a demo.
    data_gov_api_key: str = "579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b"

    # Cache TTLs, in seconds.
    weather_cache_ttl: int = 3 * 60 * 60      # 3h, matches the plan's connector table
    soil_cache_ttl: int = 30 * 24 * 60 * 60   # 30 days — SoilGrids is a static raster
    ndvi_cache_ttl: int = 5 * 24 * 60 * 60    # 5 days — one Sentinel-2 revisit cycle
    market_cache_ttl: int = 12 * 60 * 60      # 12h — Agmarknet publishes daily

    # Groq — the one paid-capable service in this file, but has a free tier.
    # The advisory agent (Phase 4, app/agent/) needs an LLM for every node;
    # nothing else in this backend does. Get a key at console.groq.com and
    # put it in backend/.env — never commit it.
    groq_api_key: str = ""
    groq_model: str = "openai/gpt-oss-120b"


@lru_cache
def get_settings() -> Settings:
    return Settings()
