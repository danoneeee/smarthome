import asyncio
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.models.user import User
from app.models.house import House
from app.models.room import Room
from app.models.device import Device, DeviceType
from app.models.event import EventLog
from app.schemas.device import (
    DeviceCreate,
    DeviceUpdate,
    DeviceResponse,
    DeviceCommand,
    DeviceTypeResponse,
)
from app.core.config import get_settings
from app.core.mqtt import publish_command
from app.api.deps import get_current_user

router = APIRouter(prefix="/devices", tags=["Устройства"])


async def _device_with_access(db: AsyncSession, device_id: int, user_id: int) -> Device | None:
    result = await db.execute(
        select(Device).where(Device.id == device_id, Device.user_id == user_id).options(
            selectinload(Device.device_type),
            selectinload(Device.room),
        )
    )
    return result.scalar_one_or_none()


def _device_to_response(d: Device) -> DeviceResponse:
    return DeviceResponse(
        id=d.id,
        name=d.name,
        type_id=d.type_id,
        room_id=d.room_id,
        status=d.status,
        last_seen=d.last_seen,
        metadata_=d.metadata_,
        created_at=d.created_at,
        device_type=DeviceTypeResponse.model_validate(d.device_type) if d.device_type else None,
        room_name=d.room.name if d.room else None,
    )


@router.get("/types", response_model=list[DeviceTypeResponse])
async def list_device_types(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(DeviceType))
    return list(result.scalars().all())


@router.get("", response_model=list[DeviceResponse])
async def list_devices(
    room_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = (
        select(Device)
        .where(Device.user_id == current_user.id)
        .options(selectinload(Device.device_type), selectinload(Device.room))
    )
    if room_id is not None:
        q = q.where(Device.room_id == room_id)
    result = await db.execute(q)
    return [_device_to_response(d) for d in result.scalars().all()]


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def create_device(
    data: DeviceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    settings = get_settings()
    count_result = await db.execute(select(Device).where(Device.user_id == current_user.id))
    if len(count_result.scalars().all()) >= settings.max_devices_per_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Достигнут лимит устройств ({settings.max_devices_per_user})",
        )
    if data.room_id is not None:
        room_result = await db.execute(
            select(Room).join(House).where(Room.id == data.room_id, House.user_id == current_user.id)
        )
        if not room_result.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комната не найдена")
    device = Device(
        user_id=current_user.id,
        name=data.name,
        type_id=data.type_id,
        room_id=data.room_id,
        serial_number=data.serial_number,
        status="offline",
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    await db.refresh(device, ["device_type", "room"])
    return _device_to_response(device)


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = await _device_with_access(db, device_id, current_user.id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Устройство не найдено")
    return _device_to_response(device)


@router.patch("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: int,
    data: DeviceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = await _device_with_access(db, device_id, current_user.id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Устройство не найдено")
    if data.name is not None:
        device.name = data.name
    if data.room_id is not None:
        room_result = await db.execute(
            select(Room).join(House).where(Room.id == data.room_id, House.user_id == current_user.id)
        )
        if not room_result.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комната не найдена")
        device.room_id = data.room_id
    await db.flush()
    await db.refresh(device)
    await db.refresh(device, ["device_type", "room"])
    return _device_to_response(device)


@router.post("/{device_id}/command", response_model=dict)
async def send_command(
    device_id: int,
    body: DeviceCommand,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = await _device_with_access(db, device_id, current_user.id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Устройство не найдено")
    if get_settings().mqtt_enabled:
        await asyncio.to_thread(
            publish_command,
            current_user.id,
            device_id,
            body.command,
            body.params,
        )
    device.last_seen = datetime.now(timezone.utc)
    device.status = "online"
    meta = dict(device.metadata_ or {})
    if body.command == "turn_on":
        meta["state"] = "on"
    elif body.command == "turn_off":
        meta["state"] = "off"
    elif body.command == "set_temperature" and body.params:
        meta["temperature"] = body.params.get("value")
    device.metadata_ = meta
    event = EventLog(
        device_id=device.id,
        name=body.command,
        event_type="command",
        description=f"Команда {body.command}",
        value=str(body.params) if body.params else None,
    )
    db.add(event)
    if body.command == "turn_on":
        power_w = (device.metadata_ or {}).get("power_watts", 10)
        kwh = round(power_w * 1.0 / 1000, 3)
        db.add(EventLog(
            device_id=device.id, name="energy", event_type="energy",
            description="Расход за сессию", value=str(kwh),
        ))
    await db.commit()
    return {"ok": True, "command": body.command, "device_id": device_id}


@router.get("/{device_id}/log", response_model=list[dict])
async def device_log(
    device_id: int,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = await _device_with_access(db, device_id, current_user.id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Устройство не найдено")
    result = await db.execute(
        select(EventLog)
        .where(EventLog.device_id == device_id)
        .order_by(EventLog.created_at.desc())
        .limit(limit)
    )
    events = result.scalars().all()
    return [
        {
            "id": e.id,
            "event_type": e.event_type,
            "name": e.name,
            "description": e.description,
            "value": e.value,
            "created_at": e.created_at.isoformat().replace("+00:00", "Z") if e.created_at else None,
        }
        for e in events
    ]


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = await _device_with_access(db, device_id, current_user.id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Устройство не найдено")
    await db.delete(device)
    return None
