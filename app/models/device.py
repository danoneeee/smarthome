from datetime import datetime
from sqlalchemy import String, Integer, DateTime, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base


class DeviceType(Base):
    __tablename__ = "device_types"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)
    category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    supported_commands: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    devices: Mapped[list["Device"]] = relationship("Device", back_populates="device_type")


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    serial_number: Mapped[str | None] = mapped_column(String(100), unique=True, nullable=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type_id: Mapped[int] = mapped_column(Integer, ForeignKey("device_types.id"), nullable=False)
    room_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("rooms.id"), nullable=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="offline")
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    device_type: Mapped["DeviceType"] = relationship("DeviceType", back_populates="devices")
    room: Mapped["Room | None"] = relationship("Room", back_populates="devices")
    user: Mapped["User"] = relationship("User", back_populates="devices")
    scenario_devices: Mapped[list["ScenarioDevice"]] = relationship("ScenarioDevice", back_populates="device")

    def __repr__(self):
        return f"<Device {self.name}>"
