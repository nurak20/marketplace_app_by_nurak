import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/app_theme.dart';
import 'core/notification_hub.dart';
import 'core/session_store.dart';
import 'core/singleton.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/splash_screen.dart';
import 'features/chats/chat_screens.dart';
import 'features/dev/api_base_url_screen.dart';
import 'features/marketplace/marketplace_screens.dart';
import 'features/marketplace/comments_screen.dart';
import 'features/marketplace/search_screen.dart';
import 'features/management/management_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/payroll/my_payslips_screen.dart';
import 'features/payroll/payroll_screen.dart';
import 'features/profile/change_password_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/reviews/review_screen.dart';
import 'shell/app_shell.dart';

CustomTransitionPage<void> _fadeTabPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await api.initialize();
  NotificationHub.instance.start();
  if (kIsWeb) usePathUrlStrategy();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('km')],
      path: 'lib/assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      useFallbackTranslations: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<Singleton>.value(value: Singleton.instance),
          ChangeNotifierProvider<NotificationHub>.value(
            value: NotificationHub.instance,
          ),
        ],
        child: const MarketplaceApp(),
      ),
    ),
  );
}

class MarketplaceApp extends StatefulWidget {
  const MarketplaceApp({super.key});

  @override
  State<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends State<MarketplaceApp> {
  late final GoRouter _router = GoRouter(
    navigatorKey: Singleton.instance.navigatorKey,
    initialLocation: '/splash',
    refreshListenable: SessionStore.instance,
    redirect: _authRedirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      if (kDebugMode)
        GoRoute(
          path: '/api-settings',
          builder: (_, _) => const ApiBaseUrlScreen(),
        ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _fadeTabPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/saved',
            pageBuilder: (_, state) => _fadeTabPage(state, const SavedScreen()),
          ),
          GoRoute(
            path: '/sell',
            pageBuilder: (_, state) => _fadeTabPage(state, const SellScreen()),
          ),
          GoRoute(
            path: '/chats',
            pageBuilder: (_, state) => _fadeTabPage(state, const ChatsScreen()),
          ),
          GoRoute(
            path: '/chats/:userId',
            builder: (_, state) => ConversationScreen(
              userId: int.parse(state.pathParameters['userId']!),
              productId: int.tryParse(
                state.uri.queryParameters['productId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (_, state) =>
                _fadeTabPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: '/me/payslips',
            builder: (_, _) => const MyPayslipsScreen(),
          ),
          GoRoute(
            path: '/me/change-password',
            builder: (_, _) => const ChangePasswordScreen(),
          ),
          GoRoute(path: '/payroll', builder: (_, _) => const PayrollScreen()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(
            path: '/management',
            builder: (_, _) => const ManagementScreen(),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (_, state) => MaterialPage<void>(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const ProductSearchScreen(),
            ),
          ),
          GoRoute(
            path: '/products/:id',
            builder: (_, state) => ProductDetailScreen(
              productId: int.parse(state.pathParameters['id']!),
              postId: int.tryParse(state.uri.queryParameters['postId'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/posts/:postId/products/:productId/comments',
            builder: (_, state) => ProductCommentsScreen(
              postId: int.parse(state.pathParameters['postId']!),
              productId: int.parse(state.pathParameters['productId']!),
            ),
          ),
          GoRoute(
            path: '/products/:id/reviews',
            builder: (_, state) => ProductReviewsScreen(
              productId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/reviews/:id',
            builder: (_, state) =>
                ReviewScreen(productId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );

  String? _authRedirect(BuildContext context, GoRouterState state) {
    final session = SessionStore.instance;
    final location = state.matchedLocation;
    if (kDebugMode && location == '/api-settings') return null;

    if (!session.isInitialized) {
      return location == '/splash' ? null : '/splash';
    }

    if (location == '/splash') {
      return session.isAuthenticated ? '/' : '/login';
    }

    final onAuthPage = location == '/login' || location == '/register';
    if (!session.isAuthenticated && !onAuthPage) return '/login';
    if (session.isAuthenticated && onAuthPage) return '/';
    if (session.isAuthenticated &&
        location == '/sell' &&
        Singleton.instance.account?.canSell == false) {
      return '/';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localization = EasyLocalization.of(context)!;
    return MaterialApp.router(
      title: 'Nurak MK27',
      themeMode: ThemeMode.system,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      // Keep large accessibility text from breaking fixed-height rows and chips.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
      locale: localization.locale,
      supportedLocales: localization.supportedLocales,
      localizationsDelegates: localization.delegates,
      routerConfig: _router,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
