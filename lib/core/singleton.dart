import 'package:flutter/material.dart';

import 'models.dart';

class Singleton extends ChangeNotifier {
  Singleton._();

  static final Singleton instance = Singleton._();

  final navigatorKey = GlobalKey<NavigatorState>();

  Account? _account;

  Account? get account => _account;
  UserProfile? get userProfile => _account?.profile;

  void setAccount(Account account) {
    _account = account;
    notifyListeners();
  }

  void clear() {
    if (_account == null) return;
    _account = null;
    notifyListeners();
  }
}
