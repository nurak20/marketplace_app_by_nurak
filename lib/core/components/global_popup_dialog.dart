import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';

abstract final class GlobalPopupDialog {
  static DialogRoute<void>? _loadingRoute;
  static NavigatorState? _loadingNavigator;
  static int _loadingRequests = 0;
  static bool _manualLoading = false;

  static Future<bool?> yesNoPrompt(
    BuildContext context, {
    required String title,
    required String message,
    String yesText = 'Yes',
    String noText = 'No',
  }) => showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _title(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: _buttonText(noText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: StyleColor.ink,
            foregroundColor: Colors.white,
          ),
          child: _buttonText(yesText),
        ),
      ],
    ),
  );

  static Future<void> success(
    BuildContext context, {
    required String message,
    String title = 'Success',
    String buttonText = 'OK',
  }) => _status(
    context,
    title: title,
    message: message,
    buttonText: buttonText,
    icon: Icons.check_circle_outline_rounded,
    color: StyleColor.success,
  );

  static Future<void> failed(
    BuildContext context, {
    required String message,
    String title = 'Something went wrong',
    String buttonText = 'OK',
  }) => _status(
    context,
    title: title,
    message: message,
    buttonText: buttonText,
    icon: Icons.error_outline_rounded,
    color: Theme.of(context).colorScheme.error,
  );

  static Future<void> _status(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required IconData icon,
    required Color color,
  }) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, size: StyleColor.iconSize, color: color),
            const SizedBox(width: 10),
            Expanded(child: _title(title)),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: StyleColor.ink,
              foregroundColor: Colors.white,
            ),
            child: _buttonText(buttonText),
          ),
        ],
      ),
    );
  }

  static void loading(BuildContext context, {String message = 'Loading...'}) {
    _manualLoading = true;
    _showLoadingRoute(context, message);
  }

  static void _showLoadingRoute(BuildContext context, String message) {
    if (_loadingRoute?.isActive == true) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: StyleColor.ink,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
    _loadingNavigator = navigator;
    _loadingRoute = route;
    unawaited(
      navigator.push<void>(route).whenComplete(() {
        if (identical(_loadingRoute, route)) {
          _loadingRoute = null;
          _loadingNavigator = null;
          _manualLoading = false;
        }
      }),
    );
  }

  static void hideLoading() {
    _manualLoading = false;
    _removeLoadingIfIdle();
  }

  static void _removeLoadingIfIdle() {
    if (_manualLoading || _loadingRequests > 0) return;
    final route = _loadingRoute;
    final navigator = _loadingNavigator;
    _loadingRoute = null;
    _loadingNavigator = null;
    if (route != null && route.isActive && navigator?.mounted == true) {
      navigator!.removeRoute(route);
    }
  }

  static Future<T> withLoading<T>(
    BuildContext context,
    Future<T> Function() request, {
    String message = 'Loading...',
  }) async {
    _loadingRequests++;
    _showLoadingRoute(context, message);
    try {
      return await request();
    } finally {
      _loadingRequests--;
      _removeLoadingIfIdle();
    }
  }

  static Text _title(String value) => Text(
    value,
    style: const TextStyle(
      color: StyleColor.ink,
      fontSize: StyleFont.largeSize,
      fontWeight: FontWeight.w400,
    ),
  );

  static Text _buttonText(String value) => Text(
    value,
    style: const TextStyle(
      fontSize: StyleFont.mediumSize,
      fontWeight: FontWeight.w400,
    ),
  );
}
