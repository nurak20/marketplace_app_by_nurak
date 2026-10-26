import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'singleton.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _tokenKey = 'marketplace.access_token';
  late final SharedPreferences _preferences;
  bool _storageInitialized = false;
  bool _initializationComplete = false;
  bool _authenticated = false;
  String? _token;

  String? get token => _token;
  bool get isInitialized => _initializationComplete;
  bool get isAuthenticated => _initializationComplete && _authenticated;

  Future<void> initialize() async {
    if (_storageInitialized) return;
    _preferences = await SharedPreferences.getInstance();
    _token = _preferences.getString(_tokenKey);
    _storageInitialized = true;
  }

  void completeInitialization({required bool authenticated}) {
    _initializationComplete = true;
    _authenticated = authenticated && _token?.isNotEmpty == true;
    notifyListeners();
  }

  Future<void> saveToken(String token, {bool notify = true}) async {
    _token = token;
    _authenticated = token.isNotEmpty;
    _initializationComplete = true;
    await _preferences.setString(_tokenKey, token);
    if (notify) notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _authenticated = false;
    try {
      if (_storageInitialized) await _preferences.remove(_tokenKey);
    } finally {
      Singleton.instance.clear();
      notifyListeners();
    }
  }
}
