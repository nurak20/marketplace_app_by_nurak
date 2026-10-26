import 'package:flutter/material.dart';

import '../../shell/bottom_navigation_visibility.dart';

/// Prompts before opening the platform image picker on web and mobile.
Future<bool> showChooseImageBottomSheet(BuildContext context) async {
  final chooseImage = await hideBottomNavigationWhile(
    () => showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('Choose Image'),
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    ),
  );

  return chooseImage == true;
}
