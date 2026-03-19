from pydantic import BaseModel


class UserRegister(BaseModel):
    email: str
    password: str
    name: str
    surname: str
    patronymic: str | None = None
    phone: str | None = None


class UserLogin(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    surname: str
    patronymic: str | None
    language: str

    class Config:
        from_attributes = True
