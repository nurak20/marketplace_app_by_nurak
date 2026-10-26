import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/session_store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final session = SessionStore.instance;
    final loading = GlobalPopupDialog.showLoading(content: 'Loading....');
    var authenticated = false;

    try {
      await session.initialize();

      if (session.token?.isNotEmpty == true) {
        await api.me();
        authenticated = true;
      }
    } catch (_) {
      try {
        await session.clear();
      } catch (_) {
        // Keep the user signed out in memory even if token removal fails.
      }
    } finally {
      loading?.close();
      session.completeInitialization(authenticated: authenticated);
      if (mounted) context.go(authenticated ? '/' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
