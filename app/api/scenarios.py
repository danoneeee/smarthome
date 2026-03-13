import asyncio
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.mqtt import publish_command
from app.db.session import get_db
from app.models.user import User
from app.models.device import Device
from app.models.scenario import Scenario, ScenarioDevice
from app.models.event import EventLog
from app.schemas.scenario import ScenarioCreate, ScenarioUpdate, ScenarioResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/scenarios", tags=["Сценарии"])


async def _scenario_with_actions(db: AsyncSession, scenario_id: int, user_id: int) -> Scenario | None:
    result = await db.execute(
        select(Scenario)
        .where(Scenario.id == scenario_id, Scenario.user_id == user_id)
        .options(selectinload(Scenario.scenario_devices))
    )
    return result.scalar_one_or_none()


def _scenario_to_response(s: Scenario) -> ScenarioResponse:
    actions = [
        {"device_id": sd.device_id, "action": sd.action, "action_params": sd.action_params}
        for sd in s.scenario_devices
    ]
    return ScenarioResponse(
        id=s.id,
        name=s.name,
        trigger_type=s.trigger_type,
        trigger_config=s.trigger_config,
        is_active=s.is_active,
        created_at=s.created_at,
        device_actions=actions,
    )


@router.get("", response_model=list[ScenarioResponse])
async def list_scenarios(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Scenario)
        .where(Scenario.user_id == current_user.id)
        .options(selectinload(Scenario.scenario_devices))
    )
    return [_scenario_to_response(s) for s in result.scalars().all()]


@router.post("", response_model=ScenarioResponse, status_code=status.HTTP_201_CREATED)
async def create_scenario(
    data: ScenarioCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = Scenario(
        user_id=current_user.id,
        name=data.name,
        trigger_type=data.trigger_type or "manual",
        trigger_config=data.trigger_config,
        is_active=True,
    )
    db.add(scenario)
    await db.flush()
    for act in data.device_actions:
        res = await db.execute(select(Device).where(Device.id == act.device_id, Device.user_id == current_user.id))
        if res.scalar_one_or_none():
            sd = ScenarioDevice(
                scenario_id=scenario.id,
                device_id=act.device_id,
                action=act.action,
                action_params=act.action_params,
            )
            db.add(sd)
    await db.flush()
    await db.refresh(scenario)
    await db.refresh(scenario, ["scenario_devices"])
    return _scenario_to_response(scenario)


@router.get("/{scenario_id}", response_model=ScenarioResponse)
async def get_scenario(
    scenario_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = await _scenario_with_actions(db, scenario_id, current_user.id)
    if not scenario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сценарий не найден")
    return _scenario_to_response(scenario)


@router.patch("/{scenario_id}", response_model=ScenarioResponse)
async def update_scenario(
    scenario_id: int,
    data: ScenarioUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = await _scenario_with_actions(db, scenario_id, current_user.id)
    if not scenario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сценарий не найден")
    if data.name is not None:
        scenario.name = data.name
    if data.trigger_type is not None:
        scenario.trigger_type = data.trigger_type
    if data.trigger_config is not None:
        scenario.trigger_config = data.trigger_config
    if data.is_active is not None:
        scenario.is_active = data.is_active
    if data.device_actions is not None:
        for sd in scenario.scenario_devices:
            await db.delete(sd)
        await db.flush()
        for act in data.device_actions:
            res = await db.execute(select(Device).where(Device.id == act.device_id, Device.user_id == current_user.id))
            if res.scalar_one_or_none():
                sd = ScenarioDevice(
                    scenario_id=scenario.id,
                    device_id=act.device_id,
                    action=act.action,
                    action_params=act.action_params,
                )
                db.add(sd)
    await db.flush()
    await db.refresh(scenario)
    await db.refresh(scenario, ["scenario_devices"])
    return _scenario_to_response(scenario)


@router.post("/{scenario_id}/run", response_model=dict)
async def run_scenario(
    scenario_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = await _scenario_with_actions(db, scenario_id, current_user.id)
    if not scenario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сценарий не найден")
    results: list[dict] = []
    mqtt_on = get_settings().mqtt_enabled
    for sd in scenario.scenario_devices:
        dev_result = await db.execute(
            select(Device).where(Device.id == sd.device_id, Device.user_id == current_user.id)
        )
        device = dev_result.scalar_one_or_none()
        sent = False
        if mqtt_on:
            sent = await asyncio.to_thread(
                publish_command, current_user.id, sd.device_id, sd.action, sd.action_params,
            )
        if device:
            device.last_seen = datetime.now(timezone.utc)
            device.status = "online"
            meta = dict(device.metadata_ or {})
            if sd.action == "turn_on":
                meta["state"] = "on"
            elif sd.action == "turn_off":
                meta["state"] = "off"
            elif sd.action == "set_temperature" and sd.action_params:
                meta["temperature"] = sd.action_params.get("value")
            device.metadata_ = meta
        status_text = "mqtt_sent" if sent else "applied"
        db.add(EventLog(
            device_id=sd.device_id,
            name=sd.action,
            event_type="scenario",
            description=f"Сценарий «{scenario.name}»: {sd.action}",
            value=status_text,
        ))
        results.append({
            "device_id": sd.device_id,
            "device_name": device.name if device else None,
            "action": sd.action,
            "status": status_text,
        })
    await db.flush()
    return {
        "ok": True,
        "scenario_id": scenario_id,
        "message": f"Сценарий «{scenario.name}» выполнен",
        "results": results,
    }


@router.delete("/{scenario_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_scenario(
    scenario_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = await _scenario_with_actions(db, scenario_id, current_user.id)
    if not scenario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сценарий не найден")
    await db.delete(scenario)
    return None
