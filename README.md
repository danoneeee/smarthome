# SmartHome Controller API (v4)

FastAPI, SQLite, модели User, House, HouseUser, Room, DeviceType, Device, EventLog, сидер типов устройств.

Эндпоинты:
- GET / — главная страница
- GET /api/health — проверка API
- POST /api/auth/register — регистрация
- POST /api/auth/login — вход (JWT)
- POST /api/auth/refresh — обновление токенов
- GET /api/auth/me — текущий пользователь
- GET/POST /api/houses, GET/PATCH/DELETE /api/houses/{id} — дома
- GET/POST /api/rooms, GET/PATCH/DELETE /api/rooms/{id} — комнаты
- GET /api/devices/types — типы устройств
- GET/POST /api/devices, GET/PATCH/DELETE /api/devices/{id} — устройства
- POST /api/devices/{id}/command — команда устройству
- GET /api/devices/{id}/log — журнал устройства

MQTT: при заданном MQTT_HOST в .env команды уходят в брокер.

Запуск: python -m venv venv && source venv/bin/activate && pip install -r requirements.txt && ./run.sh

Документация: http://127.0.0.1:8000/docs
