import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import 'empty_state.dart';

class ErrorRetryPanel extends StatelessWidget {
  const ErrorRetryPanel({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (Api.failureType(error)) {
      ApiFailureType.cancelled => Icons.cancel_outlined,
      ApiFailureType.timeout => Icons.timer_off_outlined,
      ApiFailureType.connection => Icons.wifi_off_rounded,
      ApiFailureType.server => Icons.cloud_off_outlined,
      ApiFailureType.unknown => Icons.error_outline_rounded,
    };
    return SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            title: 'common.loadFailed'.tr(),
            message: Api.errorMessage(error),
            icon: icon,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}
