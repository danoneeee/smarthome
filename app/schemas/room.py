from pydantic import BaseModel


class RoomCreate(BaseModel):
    house_id: int
    name: str
    description: str | None = None


class RoomUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


class RoomResponse(BaseModel):
    id: int
    house_id: int
    name: str
    description: str | None

    class Config:
        from_attributes = True
