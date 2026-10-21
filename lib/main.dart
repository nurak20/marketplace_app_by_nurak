import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'core/api.dart';
import 'core/app_theme.dart';
import 'core/session_store.dart';
import 'features/auth/auth_screens.dart';
import 'features/chats/chat_screens.dart';
import 'features/dev/api_base_url_screen.dart';
import 'features/marketplace/marketplace_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';
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
  await SessionStore.instance.initialize();
  await Api.instance.initialize();
  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatefulWidget {
  const MarketplaceApp({super.key});

  @override
  State<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends State<MarketplaceApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: kDebugMode ? '/api-settings' : '/',
    refreshListenable: SessionStore.instance,
    redirect: (context, state) {
      final session = SessionStore.instance;
      if (kDebugMode && state.matchedLocation == '/api-settings') return null;
      final onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!session.isAuthenticated && !onAuthPage) return '/login';
      if (session.isAuthenticated && onAuthPage) return '/';
      return null;
    },
    routes: [
      if (kDebugMode)
        GoRoute(
          path: '/api-settings',
          builder: (_, _) => const ApiBaseUrlScreen(),
        ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) =>
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
            path: '/products/:id',
            builder: (_, state) => ProductDetailScreen(
              productId: int.parse(state.pathParameters['id']!),
              showComments: state.uri.queryParameters['comments'] == 'true',
              postId: int.tryParse(state.uri.queryParameters['postId'] ?? ''),
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

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Nurak MK27',
    theme: buildAppTheme(),
    routerConfig: _router,
    debugShowCheckedModeBanner: false,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
