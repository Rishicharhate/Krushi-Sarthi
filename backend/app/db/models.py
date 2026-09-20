"""ORM models.

Auth note: the Flutter app has no login screen today (checked — only
profile/edit_profile exist, no sign-in flow). So `User` is device-bound, not
password-bound: the app calls POST /api/auth/register once with a locally
generated device id, gets a token back, and stores it. This is deliberately
the smallest thing that makes farms/data private-per-install without forcing
a login UI into scope right now. Swap in real accounts later without touching
anything downstream of `get_current_user`.
"""
from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    device_id: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    mobile: Mapped[str | None] = mapped_column(String(20), nullable=True)
    village: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
    state: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    farms: Mapped[list["Farm"]] = relationship(back_populates="owner", cascade="all, delete-orphan")


class Farm(Base):
    __tablename__ = "farms"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)

    name: Mapped[str] = mapped_column(String(120))
    location: Mapped[str | None] = mapped_column(String(255), nullable=True)
    area: Mapped[float] = mapped_column(Float)
    area_unit: Mapped[str] = mapped_column(String(20), default="Acres")
    crop: Mapped[str] = mapped_column(String(80))
    sowing_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    soil_type: Mapped[str | None] = mapped_column(String(60), nullable=True)
    is_active: Mapped[bool] = mapped_column(default=False)

    # Every downstream data source (weather, soil, NDVI) is geospatial —
    # without these a farm cannot be advised on at all.
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    owner: Mapped["User"] = relationship(back_populates="farms")


class DiseaseScan(Base):
    """One photo submitted to /api/disease/detect, with the cascade's verdict.
    Persisted per user so /api/disease/history has something real to show
    instead of staying mock-only in real mode."""
    __tablename__ = "disease_scans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)

    disease: Mapped[str] = mapped_column(String(160))
    confidence: Mapped[float] = mapped_column(Float)
    crop: Mapped[str | None] = mapped_column(String(80), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    symptoms: Mapped[str | None] = mapped_column(Text, nullable=True)
    recommendation: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_path: Mapped[str] = mapped_column(String(255))
    scanned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class ApiCache(Base):
    """Generic TTL cache for external API responses (Open-Meteo, SoilGrids, ...).

    SoilGrids' fair-use policy is ~5 calls/minute and Open-Meteo's free tier is
    capped at 10k calls/day — caching isn't an optimization here, it's what
    keeps the app inside those limits at all.
    """
    __tablename__ = "api_cache"
    __table_args__ = (UniqueConstraint("cache_key", name="uq_api_cache_key"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    cache_key: Mapped[str] = mapped_column(String(255), index=True)
    payload: Mapped[str] = mapped_column(Text)
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
