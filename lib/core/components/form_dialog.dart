import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'show_error.dart';

/// Standard form dialog: validates, disables actions while saving, and keeps
/// the dialog open (showing the API error) when the request fails.
///
/// [onClosed] runs after the dialog has fully left the screen (its exit
/// transition finished), so callers can safely dispose the [TextEditingController]s
/// used by the form there. Disposing them as soon as the future completes would
/// release them while the dialog is still animating out.
Future<T?> showMarketplaceFormDialog<T>({
  required BuildContext context,
  required String title,
  required GlobalKey<FormState> formKey,
  required Widget Function(BuildContext context) content,
  required Future<T?> Function(BuildContext context) onSubmit,
  String? submitLabel,
  String? cancelLabel,
  IconData submitIcon = Icons.check_rounded,
  VoidCallback? onClosed,
}) async {
  var saving = false;
  ModalRoute<dynamic>? route;
  try {
    return await showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        route ??= ModalRoute.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              setDialogState(() => saving = true);
              try {
                final result = await onSubmit(dialogContext);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(result);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (context.mounted) showError(context, error);
              }
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(key: formKey, child: content(dialogContext)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(cancelLabel ?? 'common.cancel'.tr()),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(submitIcon),
                  label: Text(submitLabel ?? 'common.save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    if (onClosed != null) _releaseAfterClosed(route, onClosed);
  }
}

void _releaseAfterClosed(ModalRoute<dynamic>? route, VoidCallback release) {
  if (route == null) {
    release();
    return;
  }
  // ModalRoute is a TransitionRoute, so `completed` resolves after the exit
  // animation and after the overlay entry is removed.
  route.completed.whenComplete(release).ignore();
}
