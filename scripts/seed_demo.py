#!/usr/bin/env python3
"""
Создание демо-аккаунта с домом, комнатами, устройствами, сценариями
и историей энергопотребления для демонстрации.

Запуск из корня v9: python scripts/seed_demo.py
"""
import asyncio
import random
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.db.init_db import init_db
from app.core.security import get_password_hash
from app.models.user import User
from app.models.house import House, HouseUser
from app.models.room import Room
from app.models.device import Device, DeviceType
from app.models.scenario import Scenario, ScenarioDevice
from app.models.event import EventLog
from app.models.notification import Notification

DEMO_EMAIL = "demo@smarthome.ru"
DEMO_PASSWORD = "demo123"

POWER_WATTS = {
    "lamp": 12,
    "outlet": 80,
    "thermostat": 1500,
    "motion_sensor": 0.5,
    "camera": 8,
}

AVG_HOURS_PER_DAY = {
    "lamp": 5.0,
    "outlet": 3.0,
    "thermostat": 6.0,
    "motion_sensor": 24.0,
    "camera": 24.0,
}


async def seed_demo():
    await init_db()

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(User).where(User.email == DEMO_EMAIL))
        if existing.scalar_one_or_none():
            print(f"Demo user {DEMO_EMAIL} already exists, skipping.")
            return

        user = User(
            email=DEMO_EMAIL,
            password_hash=get_password_hash(DEMO_PASSWORD),
            name="Дмитрий",
            surname="Демо",
            patronymic="Сергеевич",
        )
        db.add(user)
        await db.flush()
        uid = user.id

        house = House(user_id=uid, name="Квартира на Невском", address="Невский пр., 28, СПб")
        db.add(house)
        await db.flush()
        hu = HouseUser(house_id=house.id, user_id=uid, role="owner")
        db.add(hu)

        rooms_data = ["Гостиная", "Спальня", "Кухня"]
        rooms = {}
        for rn in rooms_data:
            r = Room(house_id=house.id, name=rn)
            db.add(r)
            await db.flush()
            rooms[rn] = r.id

        types_q = await db.execute(select(DeviceType))
        device_types = {dt.name: dt for dt in types_q.scalars().all()}

        devices_plan = [
            ("Люстра", "lamp", "Гостиная"),
            ("Розетка ТВ", "outlet", "Гостиная"),
            ("Ночник", "lamp", "Спальня"),
            ("Обогреватель", "thermostat", "Спальня"),
            ("Свет кухни", "lamp", "Кухня"),
            ("Розетка чайника", "outlet", "Кухня"),
        ]
        devices = {}
        for dname, dtype, room_name in devices_plan:
            dt = device_types.get(dtype)
            if not dt:
                continue
            dev = Device(
                user_id=uid,
                name=dname,
                type_id=dt.id,
                room_id=rooms[room_name],
                status="online",
                last_seen=datetime.now(timezone.utc),
                metadata_={"state": "off", "power_watts": POWER_WATTS.get(dtype, 10)},
            )
            db.add(dev)
            await db.flush()
            devices[dname] = (dev.id, dtype)

        sc1 = Scenario(user_id=uid, name="Экономия энергии", trigger_type="manual",
                       trigger_config={"description": "Выключить всё освещение и розетки днём"}, is_active=True)
        db.add(sc1)
        await db.flush()
        for dname, (did, dtype) in devices.items():
            if dtype in ("lamp", "outlet"):
                db.add(ScenarioDevice(scenario_id=sc1.id, device_id=did, action="turn_off"))

        sc2 = Scenario(user_id=uid, name="Холодная погода", trigger_type="event",
                       trigger_config={"condition": "weather_temp < 5"}, is_active=True)
        db.add(sc2)
        await db.flush()
        heater_id = devices["Обогреватель"][0]
        db.add(ScenarioDevice(scenario_id=sc2.id, device_id=heater_id, action="turn_on"))

        sc3 = Scenario(user_id=uid, name="Вечерний режим", trigger_type="schedule",
                       trigger_config={"time": "19:00"}, is_active=True)
        db.add(sc3)
        await db.flush()
        for dname in ("Люстра", "Ночник"):
            db.add(ScenarioDevice(scenario_id=sc3.id, device_id=devices[dname][0], action="turn_on"))

        sc4 = Scenario(user_id=uid, name="Никого нет дома", trigger_type="manual",
                       trigger_config={"description": "Выключить всё при уходе"}, is_active=True)
        db.add(sc4)
        await db.flush()
        for dname, (did, dtype) in devices.items():
            if dtype != "motion_sensor":
                db.add(ScenarioDevice(scenario_id=sc4.id, device_id=did, action="turn_off"))

        await db.flush()

        now = datetime.now(timezone.utc)
        events = []
        for day_offset in range(60, 0, -1):
            day = now - timedelta(days=day_offset)
            for dname, (did, dtype) in devices.items():
                watts = POWER_WATTS.get(dtype, 10)
                avg_h = AVG_HOURS_PER_DAY.get(dtype, 2)
                boost = 1.2 if day_offset > 30 else 1.0
                hours = max(0.1, avg_h * (0.7 + random.random() * 0.6) * boost)
                kwh = round(watts * hours / 1000, 3)
                ts = day.replace(hour=random.randint(6, 22), minute=random.randint(0, 59))
                events.append(EventLog(
                    device_id=did,
                    name="energy",
                    event_type="energy",
                    description="Потребление за день",
                    value=str(kwh),
                    created_at=ts,
                ))
                if dtype in ("lamp", "outlet", "thermostat"):
                    on_time = day.replace(hour=random.randint(7, 10), minute=random.randint(0, 59))
                    off_time = day.replace(hour=random.randint(18, 23), minute=random.randint(0, 59))
                    events.append(EventLog(device_id=did, name="turn_on", event_type="command",
                                           description="Включение", value=None, created_at=on_time))
                    events.append(EventLog(device_id=did, name="turn_off", event_type="command",
                                           description="Выключение", value=None, created_at=off_time))
        for ev in events:
            db.add(ev)
        await db.flush()

        db.add(Notification(user_id=uid, title="Добро пожаловать!", body="Демо-аккаунт создан.", type="push"))
        db.add(Notification(user_id=uid, title="Совет: экономия энергии",
                            body="Используйте сценарий «Экономия энергии».", type="push"))

        await db.commit()
        print(f"Demo user created: {DEMO_EMAIL} / {DEMO_PASSWORD}")
        print(f"  House: {house.name}, Rooms: {list(rooms.keys())}, Devices: {list(devices.keys())}, Scenarios: 4")


if __name__ == "__main__":
    asyncio.run(seed_demo())
