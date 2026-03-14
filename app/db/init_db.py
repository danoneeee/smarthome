import asyncio
from sqlalchemy import select
from app.db.session import engine, Base, AsyncSessionLocal
from app.models import User, House, HouseUser, Room, Device, DeviceType, EventLog

DEVICE_TYPES = [
    {"name": "lamp", "category": "Освещение", "supported_commands": ["turn_on", "turn_off", "set_brightness"]},
    {"name": "outlet", "category": "Розетки", "supported_commands": ["turn_on", "turn_off"]},
    {"name": "thermostat", "category": "Климат", "supported_commands": ["turn_on", "turn_off", "set_temperature"]},
    {"name": "motion_sensor", "category": "Датчики", "supported_commands": []},
    {"name": "camera", "category": "Безопасность", "supported_commands": ["turn_on", "turn_off"]},
]


async def seed_device_types():
    async with AsyncSessionLocal() as db:
        for dt in DEVICE_TYPES:
            r = await db.execute(select(DeviceType).where(DeviceType.name == dt["name"]))
            if r.scalar_one_or_none() is None:
                db.add(DeviceType(**dt))
        await db.commit()


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_device_types()


if __name__ == "__main__":
    asyncio.run(init_db())
