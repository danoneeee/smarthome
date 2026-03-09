from sqlalchemy import String, Integer, JSON
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class DeviceType(Base):
    __tablename__ = "device_types"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)
    category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    supported_commands: Mapped[dict | None] = mapped_column(JSON, nullable=True)
