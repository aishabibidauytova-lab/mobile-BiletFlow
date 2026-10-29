import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'bf_token';

  static AppUser? user;

  /// Loads a saved token and checks it with the server. Returns true if signed in.
  static Future<bool> restore() async {
    final t = await _storage.read(key: _key);
    if (t == null) return false;
    api.token = t;
    try {
      user = await api.me();
      return true;
    } on ApiException catch (e) {
      if (e.unauthorized) await logout();
      // Offline etc.: keep the token, but treat as signed out for now.
      return false;
    }
  }

  static Future<void> login(String email, String password) async =>
      _save(await api.login(email, password));

  static Future<void> register(String email, String password) async =>
      _save(await api.register(email, password));

  static Future<void> _save((String, AppUser) r) async {
    api.token = r.$1;
    user = r.$2;
    await _storage.write(key: _key, value: r.$1);
  }

  static Future<void> logout() async {
    api.token = null;
    user = null;
    await _storage.delete(key: _key);
  }
}
