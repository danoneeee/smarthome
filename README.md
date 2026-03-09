# SmartHome Controller API (v2)

FastAPI, SQLite, модели User/House/Room/DeviceType, сидер типов устройств.

Эндпоинты:
- `GET /` — главная страница
- `GET /api/health` — проверка API
- `POST /api/auth/register` — регистрация
- `POST /api/auth/login` — вход (JWT)
- `POST /api/auth/refresh` — обновление токенов
- `GET /api/auth/me` — текущий пользователь

Запуск: `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt && ./run.sh`

Документация: http://127.0.0.1:8000/docs
