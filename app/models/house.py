from datetime import datetime
from sqlalchemy import String, Integer, DateTime, Text, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base


class House(Base):
    __tablename__ = "houses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    rooms: Mapped[list["Room"]] = relationship("Room", back_populates="house", cascade="all, delete-orphan")
    house_users: Mapped[list["HouseUser"]] = relationship("HouseUser", back_populates="house", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<House {self.name}>"


class HouseUser(Base):
    __tablename__ = "house_users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    house_id: Mapped[int] = mapped_column(Integer, ForeignKey("houses.id"), nullable=False)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    role: Mapped[str] = mapped_column(String(10), default="member")

    house: Mapped["House"] = relationship("House", back_populates="house_users")
    user: Mapped["User"] = relationship("User", back_populates="houses")
