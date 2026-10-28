import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_mobile/core/singleton.dart';
import 'package:marketplace_mobile/shell/app_shell.dart';
import 'package:provider/provider.dart';

import 'support/localized_test_app.dart';

Widget _page(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (_, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => _page('home')),
        GoRoute(
          path: '/search',
          pageBuilder: (_, state) => MaterialPage<void>(
            key: state.pageKey,
            fullscreenDialog: true,
            child: _page('search'),
          ),
        ),
        GoRoute(path: '/management', builder: (_, _) => _page('management')),
        GoRoute(path: '/payroll', builder: (_, _) => _page('payroll')),
        GoRoute(path: '/reports', builder: (_, _) => _page('reports')),
      ],
    ),
  ],
);

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await pumpLocalized(
    tester,
    localizedTestApp(
      builder: (context) {
        final localization = EasyLocalization.of(context)!;
        return ChangeNotifierProvider<Singleton>.value(
          value: Singleton.instance,
          child: MaterialApp.router(
            routerConfig: router,
            locale: localization.locale,
            supportedLocales: localization.supportedLocales,
            localizationsDelegates: localization.delegates,
          ),
        );
      },
    ),
  );
  return router;
}

void main() {
  testWidgets('bottom bar stays visible after a page is removed by go()', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    expect(find.text('Favorite'), findsOneWidget);

    router.push<void>('/search');
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
    expect(find.text('Favorite'), findsNothing);

    // Replacing the stack instead of popping used to leave the bar hidden.
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Favorite'), findsOneWidget);
  });

  testWidgets('bottom bar returns after popping a pushed page', (tester) async {
    final router = await _pumpApp(tester);

    router.push<void>('/search');
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsOneWidget);
  });

  testWidgets('bottom bar is hidden on full-screen workspace routes', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    router.go('/management');
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);

    router.go('/payroll');
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);

    router.go('/reports');
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsOneWidget);
  });
}
