import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';

/// Standard retry panel shown when a screen request fails.
class LoadErrorPanel extends StatelessWidget {
  const LoadErrorPanel({
    super.key,
    required this.error,
    required this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  final Object error;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: StyleColor.muted,
          ),
          const SizedBox(height: 10),
          Text(
            Api.errorMessage(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: StyleColor.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    ),
  );
}
