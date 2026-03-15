import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.mqtt import start_mqtt_subscribe, stop_mqtt_subscribe, consume_state_queue
from app.db.init_db import init_db
from app.api import auth, houses, rooms, devices

_mqtt_consumer_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    global _mqtt_consumer_task
    if get_settings().mqtt_enabled:
        start_mqtt_subscribe()
        _mqtt_consumer_task = asyncio.create_task(consume_state_queue())
    yield
    if _mqtt_consumer_task is not None:
        _mqtt_consumer_task.cancel()
        try:
            await _mqtt_consumer_task
        except asyncio.CancelledError:
            pass
    stop_mqtt_subscribe()

app = FastAPI(
    title="SmartHome Controller API",
    description="Клиент-серверное приложение для автоматизации управления умным домом.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(houses.router, prefix="/api")
app.include_router(rooms.router, prefix="/api")
app.include_router(devices.router, prefix="/api")


@app.get("/")
async def root():
    return {"message": "SmartHome Controller API", "docs": "/docs"}


@app.get("/api/health")
async def health():
    """Проверка доступности API."""
    return {"status": "ok"}
