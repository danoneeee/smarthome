# SmartHome Controller API (v3)

FastAPI, SQLite, модели User, House, HouseUser, Room, DeviceType, сидер типов устройств.

Эндпоинты:
- GET / — главная страница
- GET /api/health — проверка API
- POST /api/auth/register — регистрация
- POST /api/auth/login — вход (JWT)
- POST /api/auth/refresh — обновление токенов
- GET /api/auth/me — текущий пользователь
- GET/POST /api/houses, GET/PATCH/DELETE /api/houses/{id} — дома
- GET/POST /api/rooms, GET/PATCH/DELETE /api/rooms/{id} — комнаты

Запуск: python -m venv venv && source venv/bin/activate && pip install -r requirements.txt && ./run.sh

Документация: http://127.0.0.1:8000/docs
