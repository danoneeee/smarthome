/// Базовый URL backend API. Подставляется автоматически:
/// — Web (Chrome): 127.0.0.1:8000
/// — Android-эмулятор: 10.0.2.2:8000 (хост-машина)
/// — iOS/ macOS: 127.0.0.1:8000
/// Для реального телефона в Wi‑Fi замените в api_config_io.dart на IP компьютера.
export 'api_config_io.dart' if (dart.library.html) 'api_config_web.dart';
