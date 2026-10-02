import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import 'about_dialog.dart';
import 'guide_dialog.dart';
import 'theme_dialog.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.onShowHiddenChanged});

  final VoidCallback onShowHiddenChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return AlertDialog(
      title: Text(tr(context, 'settings')),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                dense: true,
                title: Text(tr(context, 'show_hidden')),
                value: s.showHidden,
                onChanged: (_) async {
                  await s.toggleHidden();
                  onShowHiddenChanged();
                },
              ),
              SwitchListTile(
                dense: true,
                title: Text(tr(context, 'left_preview')),
                value: s.showLeftPreview,
                onChanged: s.setShowLeftPreview,
              ),
              SwitchListTile(
                dense: true,
                title: Text(tr(context, 'right_preview')),
                value: s.showRightPreview,
                onChanged: s.setShowRightPreview,
              ),
              SwitchListTile(
                dense: true,
                title: Text(tr(context, 'otken_title')),
                value: s.otkenEnabled,
                onChanged: s.setOtkenEnabled,
              ),
              const Divider(),
              DropdownButtonFormField<String>(
                value: s.locale.languageCode,
                decoration:
                    InputDecoration(labelText: tr(context, 'language_title')),
                items: [
                  for (final language in L10n.nativeNames.entries)
                    DropdownMenuItem(
                      value: language.key,
                      child: Text(language.value),
                    ),
                ],
                onChanged: (code) {
                  if (code != null) s.setLocale(Locale(code));
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.help_outline),
                  label: Text(tr(context, 'guide_button')),
                  onPressed: () => showUserGuide(context),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(tr(context, 'theme_title')),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ThemeDialog(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.policy_outlined),
                  label: Text(tr(context, 'legal_information')),
                  onPressed: () => showKorunLicenses(context),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
      ],
    );
  }
}
