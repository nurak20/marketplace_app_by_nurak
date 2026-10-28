import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../app_theme.dart';
import '../singleton.dart';

class LoadingDialogHandle {
  LoadingDialogHandle._(this._onClose);

  final VoidCallback _onClose;
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    _onClose();
  }
}

abstract final class GlobalPopupDialog {
  static RawDialogRoute<void>? _loadingRoute;
  static NavigatorState? _loadingNavigator;
  static int _requestLoadingCount = 0;
  static int _manualLoadingCount = 0;
  static bool _legacyManualLoading = false;

  static Future<bool?> yesNoPrompt(
    BuildContext context, {
    required String title,
    required String message,
    String? yesText,
    String? noText,
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
          child: _buttonText(noText ?? 'common.no'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: StyleColor.ink,
            foregroundColor: Colors.white,
          ),
          child: _buttonText(yesText ?? 'common.yes'.tr()),
        ),
      ],
    ),
  );

  static Future<void> success(
    BuildContext context, {
    required String message,
    String? title,
    String? buttonText,
  }) => _status(
    context,
    title: title ?? 'common.success'.tr(),
    message: message,
    buttonText: buttonText ?? 'common.ok'.tr(),
    icon: Icons.check_circle_outline_rounded,
    color: StyleColor.success,
  );

  static Future<void> failed(
    BuildContext context, {
    required String message,
    String? title,
    String? buttonText,
  }) => _status(
    context,
    title: title ?? 'common.error'.tr(),
    message: message,
    buttonText: buttonText ?? 'common.ok'.tr(),
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

  static void loading(BuildContext context, {String? message}) {
    _legacyManualLoading = true;
    _ensureLoadingRoute(context, message ?? 'common.loading'.tr());
  }

  static LoadingDialogHandle? showLoading({
    String? content,
    bool dismiss = false,
    VoidCallback? onCancel,
  }) {
    final context = Singleton.instance.navigatorKey.currentContext;
    if (context == null || !context.mounted) return null;

    _manualLoadingCount++;
    _ensureLoadingRoute(
      context,
      content ?? 'common.loading'.tr(),
      dismiss: dismiss,
      onCancel: onCancel,
    );
    return LoadingDialogHandle._(() {
      if (_manualLoadingCount > 0) _manualLoadingCount--;
      _removeLoadingIfIdle();
    });
  }

  static LoadingDialogHandle? showRequestLoading({String? content}) {
    final context = Singleton.instance.navigatorKey.currentContext;
    if (context == null || !context.mounted) return null;
    return _showRequestLoadingAt(context, content ?? 'common.loading'.tr());
  }

  static LoadingDialogHandle _showRequestLoadingAt(
    BuildContext context,
    String content,
  ) {
    _requestLoadingCount++;
    _ensureLoadingRoute(context, content);
    return LoadingDialogHandle._(() {
      if (_requestLoadingCount > 0) _requestLoadingCount--;
      _removeLoadingIfIdle();
    });
  }

  static void _ensureLoadingRoute(
    BuildContext context,
    String message, {
    bool dismiss = false,
    VoidCallback? onCancel,
  }) {
    if (_loadingRoute?.isActive == true) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final route = RawDialogRoute<void>(
      barrierColor: Colors.white.withValues(alpha: .8),
      barrierDismissible: dismiss,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      settings: const RouteSettings(name: 'marketplace/loading'),
      pageBuilder: (_, _, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(color: Colors.white.withValues(alpha: .01)),
              ),
            ),
            Center(
              child: _LoadingDialogContent(
                content: message,
                onCancel: onCancel,
              ),
            ),
          ],
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
          _manualLoadingCount = 0;
          _legacyManualLoading = false;
        }
      }),
    );
  }

  static void hideLoading() {
    _legacyManualLoading = false;
    _manualLoadingCount = 0;
    _removeLoadingIfIdle();
  }

  static void _removeLoadingIfIdle() {
    if (_legacyManualLoading ||
        _manualLoadingCount > 0 ||
        _requestLoadingCount > 0) {
      return;
    }
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
    String? message,
  }) async {
    final handle = _showRequestLoadingAt(
      context,
      message ?? 'common.loading'.tr(),
    );
    try {
      return await request();
    } finally {
      handle.close();
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

class _LoadingDialogContent extends StatefulWidget {
  const _LoadingDialogContent({required this.content, this.onCancel});

  final String content;
  final VoidCallback? onCancel;

  @override
  State<_LoadingDialogContent> createState() => _LoadingDialogContentState();
}

class _LoadingDialogContentState extends State<_LoadingDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    height: 240,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.zero,
      color: Colors.transparent,
    ),
    alignment: Alignment.center,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 100, end: 0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              final progress = 1 - value / 100;
              return Opacity(
                opacity: progress.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: (0.6 + progress * 0.4).clamp(0.3, 1.0).toDouble(),
                  child: child,
                ),
              );
            },
            child: Lottie.asset(
              'lib/assets/lotties/loading.json',
              width: 110,
              height: 110,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _shimmer,
          builder: (context, child) {
            final start = -2 + _shimmer.value * 4;
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(start, 0),
                end: Alignment(start + 2, 0),
                colors: [
                  StyleColor.muted.withValues(alpha: .4),
                  StyleColor.ink,
                  StyleColor.muted.withValues(alpha: .4),
                ],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: child,
            );
          },
          child: Text(
            widget.content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: StyleColor.muted,
              fontSize: StyleFont.largeSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onCancel,
            child: Text('common.cancel'.tr()),
          ),
        ],
      ],
    ),
  );
}
