from datetime import datetime
from pydantic import BaseModel


class ScenarioDeviceAction(BaseModel):
    device_id: int
    action: str
    action_params: dict | None = None


class ScenarioCreate(BaseModel):
    name: str
    trigger_type: str | None = "manual"
    trigger_config: dict | None = None
    device_actions: list[ScenarioDeviceAction] = []


class ScenarioUpdate(BaseModel):
    name: str | None = None
    trigger_type: str | None = None
    trigger_config: dict | None = None
    is_active: bool | None = None
    device_actions: list[ScenarioDeviceAction] | None = None


class ScenarioResponse(BaseModel):
    id: int
    name: str
    trigger_type: str | None
    trigger_config: dict | None
    is_active: bool
    created_at: datetime
    device_actions: list[dict] = []

    class Config:
        from_attributes = True
