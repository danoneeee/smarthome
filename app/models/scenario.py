from datetime import datetime
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base


class Scenario(Base):
    __tablename__ = "scenarios"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    trigger_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    trigger_config: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="scenarios")
    scenario_devices: Mapped[list["ScenarioDevice"]] = relationship(
        "ScenarioDevice", back_populates="scenario", cascade="all, delete-orphan"
    )

    def __repr__(self):
        return f"<Scenario {self.name}>"


class ScenarioDevice(Base):
    __tablename__ = "scenario_devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    scenario_id: Mapped[int] = mapped_column(Integer, ForeignKey("scenarios.id"), nullable=False)
    device_id: Mapped[int] = mapped_column(Integer, ForeignKey("devices.id"), nullable=False)
    action: Mapped[str | None] = mapped_column(String(100), nullable=True)
    action_params: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    scenario: Mapped["Scenario"] = relationship("Scenario", back_populates="scenario_devices")
    device: Mapped["Device"] = relationship("Device", back_populates="scenario_devices")
