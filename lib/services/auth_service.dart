import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'bf_token';

  /// Loads a saved token into the API client. Returns true if signed in.
  static Future<bool> restore() async {
    final t = await _storage.read(key: _key);
    if (t == null) return false;
    api.token = t;
    return true;
  }

  static Future<void> login(String email, String password) async {
    final t = await api.login(email, password);
    api.token = t;
    await _storage.write(key: _key, value: t);
  }

  static Future<void> logout() async {
    api.token = null;
    await _storage.delete(key: _key);
  }
}
