#!/usr/bin/env python3
"""
Эмулятор умных устройств для SmartHome Controller.
Читает конфиг (emulator_config.json), подписывается на MQTT-команды для указанных устройств
и публикует обратно состояние (state), чтобы backend обновлял БД.

Запуск:
  cd backend/emulator && python run_emulator.py
  python run_emulator.py /path/to/emulator_config.json
"""
import json
import logging
import sys
import threading
import time
from pathlib import Path

import paho.mqtt.client as mqtt

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# Состояние каждого устройства в памяти: (user_id, device_id) -> {"state": "on", "temperature": 20, ...}
device_states: dict[tuple[int, int], dict] = {}

# Мощность по типу устройства (Вт) для расчёта реального потребления
POWER_WATTS: dict[str, float] = {
    "lamp": 12,
    "outlet": 80,
    "thermostat": 1500,
    "motion_sensor": 0.5,
    "camera": 8,
}

CONFIG_PATH = Path(__file__).resolve().parent / "emulator_config.json"


def load_config(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def command_topic(prefix: str, user_id: int, device_id: int) -> str:
    return f"{prefix}/{user_id}/{device_id}/command"


def state_topic(prefix: str, user_id: int, device_id: int) -> str:
    return f"{prefix}/{user_id}/{device_id}/state"


def apply_command(user_id: int, device_id: int, command: str, params: dict | None) -> dict:
    """Обновляет состояние устройства по команде, возвращает новое состояние для публикации."""
    key = (user_id, device_id)
    state = device_states.get(key, {"state": "off", "temperature": 20})
    params = params or {}
    if command == "turn_on":
        state["state"] = "on"
    elif command == "turn_off":
        state["state"] = "off"
    elif command == "set_temperature":
        state["temperature"] = params.get("value", state.get("temperature", 20))
    elif command == "set_brightness":
        state["brightness"] = params.get("value", state.get("brightness", 100))
    device_states[key] = state
    return state


def build_state_payload(state: dict) -> str:
    """Формат state, который ожидает backend (consume_state_queue)."""
    return json.dumps({
        "status": "online",
        "metadata": state,
    })


def heartbeat_loop(client: mqtt.Client, config: dict, interval: int = 30):
    """Периодически шлёт state всех устройств (каждые N секунд) — heartbeat / телеметрия."""
    prefix = config["mqtt"]["topic_prefix"]
    while True:
        time.sleep(interval)
        for dev in config.get("devices", []):
            uid, did = dev["user_id"], dev["device_id"]
            key = (uid, did)
            state = device_states.get(key, {"state": "off"})
            topic = state_topic(prefix, uid, did)
            client.publish(topic, build_state_payload(state), qos=1)
        logger.debug("Heartbeat sent for %d devices", len(config.get("devices", [])))


def on_connect(client: mqtt.Client, userdata, flags, reason_code, properties=None):
    if reason_code != 0:
        logger.error("MQTT connect failed: %s", reason_code)
        return
    logger.info("Connected to MQTT broker")
    cfg = userdata["config"]
    prefix = cfg["mqtt"]["topic_prefix"]
    for dev in cfg["devices"]:
        uid, did = dev["user_id"], dev["device_id"]
        topic = command_topic(prefix, uid, did)
        client.subscribe(topic, qos=1)
        device_states[(uid, did)] = {"state": "off", "temperature": 20}
        logger.info("Subscribed to %s", topic)


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage):
    try:
        parts = msg.topic.split("/")
        if len(parts) < 4:
            return
        prefix = parts[0]
        user_id, device_id = int(parts[1]), int(parts[2])
        payload = json.loads(msg.payload.decode("utf-8"))
        command = payload.get("command", "")
        params = payload.get("params") or {}
        state = apply_command(user_id, device_id, command, params)
        state_t = state_topic(prefix, user_id, device_id)
        body = build_state_payload(state)
        client.publish(state_t, body, qos=1)
        logger.info("Device %s/%s: %s -> state %s", user_id, device_id, command, state)
    except Exception as e:
        logger.warning("Message error: %s", e)


def main():
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else CONFIG_PATH
    if not config_path.is_file():
        logger.error("Config not found: %s. Copy emulator_config.example.json to emulator_config.json", config_path)
        sys.exit(1)
    config = load_config(config_path)
    mqtt_cfg = config["mqtt"]
    devices = config.get("devices", [])
    if not devices:
        logger.error("No devices in config")
        sys.exit(1)
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="smarthome-emulator")
    if mqtt_cfg.get("username"):
        client.username_pw_set(mqtt_cfg["username"], mqtt_cfg.get("password") or "")
    client.user_data_set({"config": config})
    client.on_connect = on_connect
    client.on_message = on_message
    host = mqtt_cfg.get("host", "127.0.0.1")
    port = mqtt_cfg.get("port", 1883)
    heartbeat_sec = config.get("heartbeat_interval", 30)
    logger.info("Connecting to %s:%s, devices: %s, heartbeat: %ds", host, port, devices, heartbeat_sec)
    try:
        client.connect(host, port, 60)
    except Exception as e:
        logger.error("Connect failed: %s. Start MQTT broker (e.g. docker run -p 1883:1883 eclipse-mosquitto)", e)
        sys.exit(1)
    hb = threading.Thread(target=heartbeat_loop, args=(client, config, heartbeat_sec), daemon=True)
    hb.start()
    client.loop_forever()


if __name__ == "__main__":
    main()
