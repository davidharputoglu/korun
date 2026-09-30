import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/settings/settings_controller.dart';

/// Paramètres persistants : fichiers cachés (même état que le bouton
/// rapide de la barre + Ctrl+H) et activation d'Ötken.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _otkenEnabled = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(
        () => _otkenEnabled = p.getBool('otkenEnabled') ?? true));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return AlertDialog(
      title: Text(tr(context, 'settings')),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              dense: true,
              title: Text(tr(context, 'show_hidden')),
              value: s.showHidden,
              onChanged: (_) => s.toggleHidden(),
            ),
            SwitchListTile(
              dense: true,
              title: Text(tr(context, 'otken_title')),
              value: _otkenEnabled,
              onChanged: (v) async {
                setState(() => _otkenEnabled = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('otkenEnabled', v);
              },
            ),
          ],
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
