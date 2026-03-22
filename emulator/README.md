# Эмулятор устройств SmartHome

Программа притворяется умными устройствами: получает команды по MQTT от backend и отправляет обратно состояние. Так можно проверить цепочку «приложение → backend → MQTT → устройство» без железа.

## Конфиг: `emulator_config.json`

Структура:

```json
{
  "mqtt": {
    "host": "127.0.0.1",
    "port": 1883,
    "username": null,
    "password": null,
    "topic_prefix": "smarthome"
  },
  "devices": [
    { "user_id": 1, "device_id": 1 },
    { "user_id": 1, "device_id": 2 }
  ]
}
```

- **mqtt** — адрес и порт MQTT-брокера, логин/пароль (если есть), префикс топиков (как в backend).
- **devices** — список устройств для эмуляции. Укажите реальные `user_id` и `device_id` из вашей БД (те, что созданы в приложении). Эмулятор подпишется на команды для этих пар и будет слать state обратно.

Скопируйте `emulator_config.example.json` в `emulator_config.json` и подставьте свои `user_id` и `device_id`.

## Запуск (подключение эмулятора)

1. **Запустите MQTT-брокер** (в отдельном терминале):
   ```bash
   docker run -d -p 1883:1883 --name mosquitto eclipse-mosquitto
   ```
   Или: `brew install mosquitto && brew services start mosquitto`

2. **Включите MQTT в backend:** в корне v10 создайте `.env` с `MQTT_HOST=127.0.0.1`. Перезапустите backend (`./run.sh` в папке v10).

3. **Запустите эмулятор** (ещё один терминал):
   ```bash
   cd v10/emulator
   chmod +x run.sh && ./run.sh
   ```
   Или из корня v10: `./venv/bin/python emulator/run_emulator.py`
   С другим конфигом: `./run.sh /path/to/emulator_config.json`

В приложении отправьте команду устройству или выполните сценарий — эмулятор получит команду, обновит состояние и отправит его в backend; в приложении устройство станет «онлайн» и обновит состояние.
