import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';

class ApiBaseUrlScreen extends StatefulWidget {
  const ApiBaseUrlScreen({super.key});

  @override
  State<ApiBaseUrlScreen> createState() => _ApiBaseUrlScreenState();
}

class _ApiBaseUrlScreenState extends State<ApiBaseUrlScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: Api.instance.baseUrl,
  );
  String? _error;
  bool _saving = false;

  Future<void> _continue() async {
    final baseUrl = Api.validateBaseUrl(_controller.text);
    if (baseUrl == null) {
      setState(() {
        _error = 'Enter a valid URL starting with http:// or https://.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Api.instance.configureBaseUrl(baseUrl);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not apply the API URL. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'lib/assets/logo/mk27_app_logo.png',
                      width: 112,
                      height: 112,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: StyleColor.teal.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.construction_rounded,
                              size: 16,
                              color: StyleColor.teal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NOW UNDER DEVELOPMENT',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: StyleColor.teal,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .7,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nurak MK27',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: StyleColor.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Development setup',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: StyleColor.muted),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'API base URL',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _continue(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: const InputDecoration(
                      hintText: 'http://localhost:7001/api/v1',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'On a real phone, enter your computer’s LAN IP address '
                    'and keep both devices on the same Wi-Fi. If you switch '
                    'networks, change the .env value and restart the app. '
                    'This screen applies a temporary debug override.',
                    style: TextStyle(color: StyleColor.muted, height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open this screen from your profile to edit the API URL.',
                    style: TextStyle(
                      color: StyleColor.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _continue,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_saving ? 'Applying…' : 'Apply and continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
