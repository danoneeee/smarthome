from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.house import House, HouseUser
from app.schemas.house import HouseCreate, HouseUpdate, HouseResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/houses", tags=["Дома"])


@router.get("", response_model=list[HouseResponse])
async def list_houses(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(House).where(House.user_id == current_user.id)
    )
    return list(result.scalars().all())


@router.post("", response_model=HouseResponse, status_code=status.HTTP_201_CREATED)
async def create_house(
    data: HouseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    house = House(
        user_id=current_user.id,
        name=data.name,
        address=data.address,
    )
    db.add(house)
    await db.flush()
    hu = HouseUser(house_id=house.id, user_id=current_user.id, role="owner")
    db.add(hu)
    await db.flush()
    await db.refresh(house)
    return house


@router.get("/{house_id}", response_model=HouseResponse)
async def get_house(
    house_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(House).where(House.id == house_id, House.user_id == current_user.id)
    )
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Дом не найден")
    return house


@router.patch("/{house_id}", response_model=HouseResponse)
async def update_house(
    house_id: int,
    data: HouseUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(House).where(House.id == house_id, House.user_id == current_user.id)
    )
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Дом не найден")
    if data.name is not None:
        house.name = data.name
    if data.address is not None:
        house.address = data.address
    await db.flush()
    await db.refresh(house)
    return house


@router.delete("/{house_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_house(
    house_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(House).where(House.id == house_id, House.user_id == current_user.id)
    )
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Дом не найден")
    await db.delete(house)
    return None
