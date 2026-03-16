import 'dart:io';

/// Android-эмулятор: 10.0.2.2 = хост-машина. iOS-симулятор / macOS: 127.0.0.1
final String kApiBaseUrl = Platform.isAndroid
    ? 'http://10.0.2.2:8000/api'
    : 'http://127.0.0.1:8000/api';
