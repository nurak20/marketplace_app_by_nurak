import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isKhmer = context.locale.languageCode == 'km';
    final label = isKhmer ? 'common.khmer'.tr() : 'common.english'.tr();

    return OutlinedButton.icon(
      onPressed: () => _showLanguages(context),
      icon: const Icon(Icons.language_rounded),
      label: Text(
        compact
            ? (isKhmer ? 'ខ្មែរ' : 'EN')
            : '${'common.language'.tr()}: $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: StyleColor.ink,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: 10,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _showLanguages(BuildContext context) async {
    final currentCode = context.locale.languageCode;
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final current = sheetContext.locale.languageCode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'common.language'.tr(),
                    style: const TextStyle(
                      fontSize: StyleFont.largeSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              for (final (code, key) in const [
                ('en', 'common.english'),
                ('km', 'common.khmer'),
              ])
                ListTile(
                  leading: Icon(
                    current == code
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: current == code ? StyleColor.teal : StyleColor.muted,
                  ),
                  title: Text(key.tr()),
                  onTap: () => Navigator.of(sheetContext).pop(Locale(code)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null ||
        selected.languageCode == currentCode ||
        !context.mounted) {
      return;
    }
    await context.setLocale(selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('common.languageChanged'.tr())));
  }
}
