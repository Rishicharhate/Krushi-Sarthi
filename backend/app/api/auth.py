import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.db.database import get_db
from app.db.models import User
from app.schemas import AuthRegisterRequest, AuthResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse)
def register(body: AuthRegisterRequest, db: Session = Depends(get_db)) -> AuthResponse:
    """Idempotent: calling this again with the same device_id just logs back in.
    See the note at the top of app/db/models.py for why there's no password."""
    user = db.query(User).filter(User.device_id == body.device_id).first()
    if user is None:
        user = User(id=str(uuid.uuid4()), device_id=body.device_id, name=body.name)
        db.add(user)
        db.commit()
        db.refresh(user)
    token = create_access_token(user.id)
    return AuthResponse(token=token, user_id=user.id)
