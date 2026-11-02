import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import 'global_popup_dialog.dart';

void showError(BuildContext context, Object error) {
  if (Api.failureType(error) == ApiFailureType.cancelled) return;
  unawaited(
    GlobalPopupDialog.failed(context, message: Api.errorMessage(error)),
  );
}
