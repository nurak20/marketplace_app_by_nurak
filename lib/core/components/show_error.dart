import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import 'global_popup_dialog.dart';

void showError(BuildContext context, Object error) {
  unawaited(
    GlobalPopupDialog.failed(context, message: Api.errorMessage(error)),
  );
}
