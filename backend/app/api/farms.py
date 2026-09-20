import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Farm, User
from app.schemas import FarmIn, FarmOut

router = APIRouter(prefix="/farms", tags=["farms"])


@router.get("", response_model=list[FarmOut])
def list_farms(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> list[Farm]:
    return db.query(Farm).filter(Farm.user_id == user.id).order_by(Farm.created_at).all()


@router.post("", response_model=FarmOut, status_code=status.HTTP_201_CREATED)
def create_farm(
    body: FarmIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> Farm:
    if body.is_active:
        db.query(Farm).filter(Farm.user_id == user.id).update({"is_active": False})
    farm = Farm(id=str(uuid.uuid4()), user_id=user.id, **body.model_dump())
    db.add(farm)
    db.commit()
    db.refresh(farm)
    return farm


@router.put("/{farm_id}", response_model=FarmOut)
def update_farm(
    farm_id: str,
    body: FarmIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Farm:
    farm = db.query(Farm).filter(Farm.id == farm_id, Farm.user_id == user.id).first()
    if farm is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farm not found")
    if body.is_active:
        db.query(Farm).filter(Farm.user_id == user.id, Farm.id != farm_id).update(
            {"is_active": False}
        )
    for field, value in body.model_dump().items():
        setattr(farm, field, value)
    db.commit()
    db.refresh(farm)
    return farm


@router.delete("/{farm_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_farm(
    farm_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> None:
    farm = db.query(Farm).filter(Farm.id == farm_id, Farm.user_id == user.id).first()
    if farm is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farm not found")
    db.delete(farm)
    db.commit()
