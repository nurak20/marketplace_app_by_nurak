import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:marketplace_mobile/core/notification_hub.dart';

/// Loads the real translation files so tests assert on the same strings the
/// app ships instead of the raw keys.
class _MemoryAssetLoader extends AssetLoader {
  const _MemoryAssetLoader(this.translations);

  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations[locale.languageCode] ?? const <String, dynamic>{};
}

Map<String, Map<String, dynamic>> loadTestTranslations() {
  Map<String, dynamic> read(String code) =>
      jsonDecode(File('lib/assets/translations/$code.json').readAsStringSync())
          as Map<String, dynamic>;
  return {'en': read('en'), 'km': read('km')};
}

/// Mirrors the production `EasyLocalization` setup around [builder].
///
/// [builder] runs below the localization provider, so it can read the current
/// locale and delegates through `EasyLocalization.of(context)`.
Widget localizedTestApp({
  required Widget Function(BuildContext context) builder,
  Locale locale = const Locale('en'),
  Map<String, Map<String, dynamic>>? translations,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('km')],
    path: 'lib/assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    useOnlyLangCode: true,
    useFallbackTranslations: true,
    saveLocale: false,
    assetLoader: _MemoryAssetLoader(translations ?? loadTestTranslations()),
    child: ChangeNotifierProvider<NotificationHub>.value(
      value: NotificationHub.instance,
      child: Builder(builder: builder),
    ),
  );
}

/// Pumps [app] and lets the delegate finish loading translations.
Future<void> pumpLocalized(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pumpAndSettle();
}
