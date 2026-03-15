"""
MQTT для обмена сообщениями с устройствами. Команды в command, подписка на state.
"""
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

import paho.mqtt.client as mqtt
from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models.device import Device

logger = logging.getLogger(__name__)

CMD_TOPIC_TEMPLATE = "{prefix}/{user_id}/{device_id}/command"
STATE_TOPIC_SUBSCRIBE = "{prefix}/+/+/state"


def _topic_command(user_id: int, device_id: int) -> str:
    return CMD_TOPIC_TEMPLATE.format(
        prefix=get_settings().mqtt_topic_prefix, user_id=user_id, device_id=device_id
    )


def _client() -> mqtt.Client | None:
    s = get_settings()
    if not s.mqtt_enabled:
        return None
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="smarthome-backend")
    if s.mqtt_username:
        client.username_pw_set(s.mqtt_username, s.mqtt_password or "")
    try:
        client.connect(s.mqtt_host or "", s.mqtt_port, 60)
        return client
    except Exception as e:
        logger.warning("MQTT connect failed: %s", e)
        return None


_client_instance: mqtt.Client | None = None


def get_mqtt_client() -> mqtt.Client | None:
    global _client_instance
    if _client_instance is None and get_settings().mqtt_enabled:
        _client_instance = _client()
    return _client_instance


def publish_command(user_id: int, device_id: int, command: str, params: dict | None = None) -> bool:
    client = get_mqtt_client()
    if not client:
        return False
    topic = _topic_command(user_id, device_id)
    payload = json.dumps({"command": command, "params": params or {}}).encode("utf-8")
    try:
        client.publish(topic, payload, qos=1)
        client.loop_write()
        return True
    except Exception as e:
        logger.warning("MQTT publish failed: %s", e)
        return False


def disconnect_mqtt() -> None:
    global _client_instance
    if _client_instance:
        try:
            _client_instance.disconnect()
        except Exception:
            pass
        _client_instance = None


_state_queue: asyncio.Queue[tuple[int, int, dict]] | None = None


def get_state_queue() -> asyncio.Queue[tuple[int, int, dict]] | None:
    return _state_queue


def _on_state_message(_client: mqtt.Client, _userdata: Any, msg: mqtt.MQTTMessage) -> None:
    try:
        parts = msg.topic.split("/")
        if len(parts) < 4:
            return
        user_id, device_id = int(parts[1]), int(parts[2])
        payload = json.loads(msg.payload.decode("utf-8"))
        q = get_state_queue()
        if q and not q.full():
            q.put_nowait((user_id, device_id, payload))
    except Exception as e:
        logger.warning("MQTT state parse error: %s", e)


def start_mqtt_subscribe() -> None:
    global _state_queue
    s = get_settings()
    if not s.mqtt_enabled:
        return
    client = get_mqtt_client()
    if not client:
        return
    _state_queue = asyncio.Queue(maxsize=500)
    client.on_message = _on_state_message
    topic = STATE_TOPIC_SUBSCRIBE.format(prefix=s.mqtt_topic_prefix)
    client.subscribe(topic, qos=1)
    client.loop_start()
    logger.info("MQTT subscribed to %s", topic)


def stop_mqtt_subscribe() -> None:
    client = get_mqtt_client()
    if client:
        client.loop_stop()
    disconnect_mqtt()


async def consume_state_queue() -> None:
    q = get_state_queue()
    if not q:
        return
    while True:
        try:
            user_id, device_id, payload = await asyncio.wait_for(q.get(), timeout=5.0)
        except asyncio.TimeoutError:
            continue
        except Exception:
            break
        async with AsyncSessionLocal() as session:
            try:
                r = await session.execute(
                    select(Device).where(Device.id == device_id, Device.user_id == user_id)
                )
                device = r.scalar_one_or_none()
                if not device:
                    continue
                device.last_seen = datetime.now(timezone.utc)
                device.status = payload.get("status", "online")
                if "metadata" in payload and isinstance(payload["metadata"], dict):
                    device.metadata_ = {**(device.metadata_ or {}), **payload["metadata"]}
                await session.commit()
            except Exception as e:
                logger.warning("Failed to update device state from MQTT: %s", e)
                await session.rollback()
