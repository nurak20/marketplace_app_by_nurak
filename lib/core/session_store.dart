import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_provider.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _tokenKey = 'marketplace.access_token';
  late final SharedPreferences _preferences;
  String? _token;

  String? get token => _token;
  bool get isAuthenticated => _token?.isNotEmpty == true;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _token = _preferences.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _preferences.setString(_tokenKey, token);
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    await _preferences.remove(_tokenKey);
    profileProvider.clear();
    notifyListeners();
  }
}
