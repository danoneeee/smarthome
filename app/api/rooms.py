from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.house import House
from app.models.room import Room
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/rooms", tags=["Комнаты"])


async def _check_house_access(db: AsyncSession, house_id: int, user_id: int) -> House | None:
    result = await db.execute(select(House).where(House.id == house_id, House.user_id == user_id))
    return result.scalar_one_or_none()


@router.get("", response_model=list[RoomResponse])
async def list_rooms(
    house_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Список комнат. Если указан house_id — только комнаты этого дома."""
    q = select(Room).join(House).where(House.user_id == current_user.id)
    if house_id is not None:
        q = q.where(Room.house_id == house_id)
    result = await db.execute(q)
    return list(result.scalars().all())


@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    data: RoomCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    house = await _check_house_access(db, data.house_id, current_user.id)
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Дом не найден")
    room = Room(house_id=data.house_id, name=data.name, description=data.description)
    db.add(room)
    await db.flush()
    await db.refresh(room)
    return room


@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(
    room_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Room).join(House).where(Room.id == room_id, House.user_id == current_user.id)
    )
    room = result.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комната не найдена")
    return room


@router.patch("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: int,
    data: RoomUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Room).join(House).where(Room.id == room_id, House.user_id == current_user.id)
    )
    room = result.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комната не найдена")
    if data.name is not None:
        room.name = data.name
    if data.description is not None:
        room.description = data.description
    await db.flush()
    await db.refresh(room)
    return room


@router.delete("/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_room(
    room_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Room).join(House).where(Room.id == room_id, House.user_id == current_user.id)
    )
    room = result.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комната не найдена")
    await db.delete(room)
    return None
