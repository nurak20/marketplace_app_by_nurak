import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Prompts before opening the platform image picker on mobile.
///
/// On web the picker opens the browser's native file dialog, so the extra
/// chooser sheet is skipped.
Future<bool> showChooseImageBottomSheet(BuildContext context) async {
  if (kIsWeb) return true;

  final chooseImage = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: ListTile(
        leading: const Icon(Icons.image_outlined),
        title: Text('common.chooseImage'.tr()),
        onTap: () => Navigator.of(sheetContext).pop(true),
      ),
    ),
  );

  return chooseImage == true;
}
