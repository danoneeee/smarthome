#!/bin/bash
# Запуск эмулятора устройств (использует venv и зависимости backend).
cd "$(dirname "$0")/.."
exec ./venv/bin/python emulator/run_emulator.py "$@"
