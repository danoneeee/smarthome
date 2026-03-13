from pydantic import BaseModel


class HouseCreate(BaseModel):
    name: str
    address: str | None = None


class HouseUpdate(BaseModel):
    name: str | None = None
    address: str | None = None


class HouseResponse(BaseModel):
    id: int
    name: str
    address: str | None

    class Config:
        from_attributes = True
