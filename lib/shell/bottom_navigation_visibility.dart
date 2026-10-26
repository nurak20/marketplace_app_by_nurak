import 'package:flutter/foundation.dart';

final bottomNavigationVisible = ValueNotifier<bool>(true);

Future<T?> hideBottomNavigationWhile<T>(Future<T?> Function() show) async {
  final wasVisible = bottomNavigationVisible.value;
  bottomNavigationVisible.value = false;
  try {
    return await show();
  } finally {
    bottomNavigationVisible.value = wasVisible;
  }
}
