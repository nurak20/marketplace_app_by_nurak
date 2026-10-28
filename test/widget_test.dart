import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_mobile/core/app_theme.dart';
import 'package:marketplace_mobile/features/auth/auth_screens.dart';

import 'support/localized_test_app.dart';

Widget _app(Widget home) => localizedTestApp(
  builder: (context) {
    final localization = EasyLocalization.of(context)!;
    return MaterialApp(
      theme: buildAppTheme(),
      locale: localization.locale,
      supportedLocales: localization.supportedLocales,
      localizationsDelegates: localization.delegates,
      home: home,
    );
  },
);

void main() {
  testWidgets('shows the marketplace sign-in screen', (tester) async {
    await pumpLocalized(tester, _app(const LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('re-renders the open page when the locale changes', (
    tester,
  ) async {
    await pumpLocalized(tester, _app(const LoginScreen()));
    expect(find.text('Welcome back'), findsOneWidget);

    final context = tester.element(find.byType(LoginScreen));
    await context.setLocale(const Locale('km'));
    await tester.pumpAndSettle();

    expect(find.text('សូមស្វាគមន៍ត្រឡប់មកវិញ'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });
}
