import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/language_button.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/session_store.dart';

Future<void> _completeSignIn(String token) async {
  final session = SessionStore.instance;
  try {
    await session.saveToken(token, notify: false);
    await api.me();
  } catch (_) {
    await session.clear();
    rethrow;
  }
  session.completeInitialization(authenticated: true);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _completeSignIn(
        await api.login(_email.text.trim(), _password.text),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        _BrandMark(),
                        Spacer(),
                        LanguageButton(compact: true),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'auth.welcomeBack'.tr(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth.loginSubtitle'.tr(),
                      style: const TextStyle(color: StyleColor.muted),
                    ),
                    const SizedBox(height: 28),
                    MKTextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'auth.email'.tr(),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'auth.emailInvalid'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    MKTextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'auth.password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'auth.passwordRequired'.tr()
                          : null,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'auth.login'.tr(),
                      busy: _busy,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text('auth.createAccountPrompt'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final token = await api.register(
        username: _username.text.trim(),
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      await _completeSignIn(token);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'auth.createAccount'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
        actions: const [LanguageButton(compact: true)],
      ).build(context),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const _BrandMark(),
              const SizedBox(height: 22),
              Text(
                'auth.joinSubtitle'.tr(),
                style: const TextStyle(color: StyleColor.muted),
              ),
              const SizedBox(height: 22),
              MKTextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'auth.fullName'.tr()),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'auth.nameRequired'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              MKTextFormField(
                controller: _username,
                decoration: InputDecoration(labelText: 'auth.username'.tr()),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'auth.usernameTooShort'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              MKTextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'auth.email'.tr()),
                validator: (value) => value == null || !value.contains('@')
                    ? 'auth.emailInvalid'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              MKTextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: 'auth.password'.tr()),
                validator: (value) => value == null || value.length < 8
                    ? 'auth.passwordTooShort'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              MKTextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'auth.confirmPassword'.tr(),
                ),
                validator: (value) => value != _password.text
                    ? 'auth.passwordMismatch'.tr()
                    : null,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'auth.createAccount'.tr(),
                busy: _busy,
                onPressed: _register,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text('auth.alreadyHaveAccount'.tr()),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: StyleColor.ink,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.storefront_rounded, color: StyleColor.accent),
      ),
      const SizedBox(width: 11),
      const Text(
        'Nurak MK27',
        style: TextStyle(
          fontSize: StyleFont.largeSize,
          fontWeight: FontWeight.w400,
          color: StyleColor.ink,
        ),
      ),
    ],
  );
}
