import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _auth = AuthService();

  String? _accessToken;
  Map<String, dynamic>? user;

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;

  AuthService get authService => _auth;

  Future<void> init() async {
    try {
      _accessToken = await _auth.getStoredAccessToken();
      if (_accessToken != null) {
        _auth.api.setToken(_accessToken);
        user = await _auth.getMe();
      }
    } catch (_) {
      // Ошибка при загрузке токена/профиля — показываем экран входа
      _accessToken = null;
      user = null;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _auth.login(email, password);
    _accessToken = await _auth.getStoredAccessToken();
    user = await _auth.getMe();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String surname,
    String? patronymic,
  }) async {
    await _auth.register(
      email: email,
      password: password,
      name: name,
      surname: surname,
      patronymic: patronymic,
    );
    await login(email, password);
  }

  Future<void> logout() async {
    await _auth.clearTokens();
    _accessToken = null;
    user = null;
    notifyListeners();
  }
}
