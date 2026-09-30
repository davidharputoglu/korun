import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/settings/settings_controller.dart';

class ThemeDialog extends StatefulWidget {
  const ThemeDialog({super.key});
  @override
  State<ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<ThemeDialog> {
  final _nameController = TextEditingController();
  final _hexController = TextEditingController(text: '2DD4BF');

  Color _parseHex(String s) {
    final clean = s.replaceAll('#', '').trim();
    final v = int.tryParse(clean, radix: 16);
    if (v == null || clean.length != 6) return const Color(0xFF2DD4BF);
    return Color(0xFF000000 | v);
  }

  String _modeKey(AppThemeMode m) => switch (m) {
        AppThemeMode.light => 'mode_light',
        AppThemeMode.dark => 'mode_dark',
        AppThemeMode.oledBlack => 'mode_oled',
      };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return AlertDialog(
      title: Text(tr(context, 'theme_title')),
      content: SizedBox(
        width: 440,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in AppThemeMode.values)
              RadioListTile<AppThemeMode>(
                dense: true,
                title: Text(tr(context, _modeKey(m))),
                value: m,
                groupValue: s.mode,
                onChanged: (v) => s.setMode(v!),
              ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in SettingsController.presetAccents.entries)
                  ChoiceChip(
                    label: Text(e.key),
                    selected: s.activeThemeId == 'preset:${e.key}',
                    onSelected: (_) => s.applyPreset(e.key),
                  ),
              ],
            ),
            const Divider(),
            Text(tr(context, 'custom_themes'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final t in s.customThemes)
              ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: t.color, radius: 10),
                title: Text(t.name),
                onTap: () => s.applyCustomTheme(t.id),
                trailing: IconButton(
                  tooltip: tr(context, 'delete'),
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => s.deleteCustomTheme(t.id),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: tr(context, 'theme_name')),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(labelText: 'RRGGBB'),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'create'),
                  icon: const Icon(Icons.add),
                  onPressed: () => s.saveCustomTheme(
                    _nameController.text.isEmpty ? 'custom' : _nameController.text,
                    s.mode,
                    _parseHex(_hexController.text),
                  ),
                ),
              ],
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
