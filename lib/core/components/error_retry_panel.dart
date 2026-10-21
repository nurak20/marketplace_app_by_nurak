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
  Widget build(BuildContext context) => SizedBox(
    height: 260,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmptyState(
          title: 'Could not load this page',
          message: Api.errorMessage(error),
          icon: Icons.wifi_off_rounded,
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
