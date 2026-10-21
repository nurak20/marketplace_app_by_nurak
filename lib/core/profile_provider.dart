import 'package:flutter/foundation.dart';

import 'models.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider._();

  static final ProfileProvider instance = ProfileProvider._();

  Account? _account;

  Account? get account => _account;
  UserProfile? get profile => _account?.profile;

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

final ProfileProvider profileProvider = ProfileProvider.instance;
