from datetime import datetime
from pydantic import BaseModel, ConfigDict


class DeviceTypeResponse(BaseModel):
    id: int
    name: str
    category: str | None
    supported_commands: list | dict | None = None

    class Config:
        from_attributes = True


class DeviceCreate(BaseModel):
    name: str
    type_id: int
    room_id: int | None = None
    serial_number: str | None = None


class DeviceUpdate(BaseModel):
    name: str | None = None
    room_id: int | None = None


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type_id: int
    room_id: int | None
    status: str
    last_seen: datetime | None
    metadata_: dict | None = None
    created_at: datetime
    device_type: DeviceTypeResponse | None = None
    room_name: str | None = None


class DeviceCommand(BaseModel):
    command: str
    params: dict | None = None
