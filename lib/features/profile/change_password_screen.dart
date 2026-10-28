import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/show_error.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _submitting = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    try {
      await api.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      await GlobalPopupDialog.success(
        context,
        message: 'changePassword.success'.tr(),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateNew(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'changePassword.newRequired'.tr();
    if (password.length < 8) return 'changePassword.tooShort'.tr();
    if (password == _current.text) return 'changePassword.sameAsCurrent'.tr();
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'changePassword.confirmRequired'.tr();
    if (value != _next.text) return 'changePassword.mismatch'.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'changePassword.title'.tr(),
        showNotifications: false,
        showManagement: false,
        showProfileAvatar: false,
      ).build(context),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: StyleColor.accent.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'changePassword.hint'.tr(),
                              style: const TextStyle(color: StyleColor.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    MKTextFormField(
                      controller: _current,
                      obscureText: _obscureCurrent,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'changePassword.current'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'changePassword.currentRequired'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    MKTextFormField(
                      controller: _next,
                      obscureText: _obscureNext,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'changePassword.new'.tr(),
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscureNext = !_obscureNext),
                          icon: Icon(
                            _obscureNext
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validateNew,
                    ),
                    const SizedBox(height: 14),
                    MKTextFormField(
                      controller: _confirm,
                      obscureText: _obscureNext,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'changePassword.confirm'.tr(),
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                      validator: _validateConfirm,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text('changePassword.submit'.tr()),
                    ),
                    const SizedBox(height: StyleSpacing.bottomContentClearance),
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
