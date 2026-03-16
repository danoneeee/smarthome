import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  Future<String?> getStoredAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    _api.setToken(accessToken);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    _api.setToken(null);
  }

  ApiClient get api => _api;

  /// Регистрация
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String surname,
    String? patronymic,
  }) async {
    final res = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      'name': name,
      'surname': surname,
      if (patronymic != null && patronymic.isNotEmpty) 'patronymic': patronymic,
    });
    if (res.statusCode != 200) {
      final m = _errorMessage(res);
      throw Exception(m);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Вход
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (res.statusCode != 200) {
      final m = _errorMessage(res);
      throw Exception(m);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await saveTokens(access, refresh);
    return data;
  }

  /// Текущий пользователь
  Future<Map<String, dynamic>?> getMe() async {
    final res = await _api.get('/auth/me');
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _errorMessage(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      if (m is Map && m['detail'] != null) return m['detail'].toString();
    } catch (_) {}
    return 'Ошибка ${res.statusCode}';
  }
}
