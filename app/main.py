from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.init_db import init_db
from app.api import auth, houses, rooms, devices, scenarios, notifications, energy

_mqtt_consumer_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

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
app.include_router(scenarios.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(energy.router, prefix="/api")


@app.get("/")
async def root():
    return {"message": "SmartHome Controller API", "docs": "/docs"}


@app.get("/api/health")
async def health():
    """Проверка доступности API."""
    return {"status": "ok"}
