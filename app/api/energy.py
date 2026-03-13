from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.device import Device, DeviceType
from app.models.event import EventLog
from app.api.deps import get_current_user

router = APIRouter(prefix="/energy", tags=["Энергопотребление"])

POWER_WATTS = {
    "lamp": 12,
    "outlet": 80,
    "thermostat": 1500,
    "motion_sensor": 0.5,
    "camera": 8,
}


@router.get("/summary")
async def energy_summary(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=days)
    prev_start = period_start - timedelta(days=days)

    user_devices = await db.execute(
        select(Device).where(Device.user_id == current_user.id)
    )
    devices = list(user_devices.scalars().all())
    device_ids = [d.id for d in devices]

    if not device_ids:
        return {"total_kwh": 0, "prev_total_kwh": 0, "saving_percent": 0,
                "by_category": {}, "by_device": [], "daily": []}

    type_ids = list({d.type_id for d in devices})
    types_q = await db.execute(select(DeviceType).where(DeviceType.id.in_(type_ids)))
    types_map = {dt.id: dt for dt in types_q.scalars().all()}

    current_events = await db.execute(
        select(EventLog).where(
            EventLog.device_id.in_(device_ids),
            EventLog.event_type == "energy",
            EventLog.created_at >= period_start,
        )
    )
    current_list = list(current_events.scalars().all())

    prev_events = await db.execute(
        select(EventLog).where(
            EventLog.device_id.in_(device_ids),
            EventLog.event_type == "energy",
            EventLog.created_at >= prev_start,
            EventLog.created_at < period_start,
        )
    )
    prev_list = list(prev_events.scalars().all())

    dev_map = {d.id: d for d in devices}

    by_device_kwh: dict[int, float] = {}
    for ev in current_list:
        try:
            kwh = float(ev.value or 0)
        except (ValueError, TypeError):
            kwh = 0
        by_device_kwh[ev.device_id] = by_device_kwh.get(ev.device_id, 0) + kwh

    by_category: dict[str, float] = {}
    for did, kwh in by_device_kwh.items():
        dev = dev_map.get(did)
        if dev:
            dt = types_map.get(dev.type_id)
            cat = dt.category if dt else "Другое"
            by_category[cat] = by_category.get(cat, 0) + round(kwh, 3)

    total_kwh = round(sum(by_device_kwh.values()), 3)

    prev_total = 0.0
    for ev in prev_list:
        try:
            prev_total += float(ev.value or 0)
        except (ValueError, TypeError):
            pass
    prev_total = round(prev_total, 3)

    saving_pct = 0.0
    if prev_total > 0:
        saving_pct = round((prev_total - total_kwh) / prev_total * 100, 1)

    by_device_list = []
    for did, kwh in sorted(by_device_kwh.items(), key=lambda x: -x[1]):
        dev = dev_map.get(did)
        if dev:
            dt = types_map.get(dev.type_id)
            watts = POWER_WATTS.get(dt.name if dt else "", 10)
            by_device_list.append({
                "device_id": did,
                "device_name": dev.name,
                "category": dt.category if dt else "Другое",
                "power_watts": watts,
                "kwh": round(kwh, 3),
                "cost_rub": round(kwh * 6.43, 2),
            })

    daily: dict[str, float] = {}
    for ev in current_list:
        day_key = ev.created_at.strftime("%Y-%m-%d") if ev.created_at else "unknown"
        try:
            daily[day_key] = daily.get(day_key, 0) + float(ev.value or 0)
        except (ValueError, TypeError):
            pass
    daily_list = [{"date": k, "kwh": round(v, 3)} for k, v in sorted(daily.items())]

    return {
        "days": days,
        "total_kwh": total_kwh,
        "total_cost_rub": round(total_kwh * 6.43, 2),
        "prev_total_kwh": prev_total,
        "saving_percent": saving_pct,
        "by_category": {k: round(v, 3) for k, v in by_category.items()},
        "by_device": by_device_list,
        "daily": daily_list,
    }
