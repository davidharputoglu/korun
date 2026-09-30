import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_info.dart';
import '../../../core/i18n/l10n.dart';

class KorunAboutDialog extends StatefulWidget {
  const KorunAboutDialog({super.key});
  @override
  State<KorunAboutDialog> createState() => _KorunAboutDialogState();
}

class _KorunAboutDialogState extends State<KorunAboutDialog> {
  bool _autoUpdate = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _autoUpdate = p.getBool('autoUpdate') ?? true));
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final client = HttpClient()..userAgent = 'KorunApp/${AppInfo.version}';
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/${AppInfo.repo}/releases/latest'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final json = jsonDecode(await res.transform(utf8.decoder).join());
        final tag = (json['tag_name'] ?? '').toString().replaceAll('v', '');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tag.isNotEmpty && tag != AppInfo.version
                ? tr(context, 'update_found')
                : 'OK (${AppInfo.version})'),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Image.asset(AppInfo.logoAsset, width: 40, height: 40),
          const SizedBox(width: 12),
          Text(tr(context, 'about')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Körün', style: Theme.of(context).textTheme.titleLarge),
            Text('${tr(context, 'version')} ${AppInfo.version}'),
            Text('${tr(context, 'author')} ${AppInfo.author}'),
            const SizedBox(height: 8),
            Text(tr(context, 'disclaimer'),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            const Divider(),
            SwitchListTile(
              dense: true,
              title: Text(tr(context, 'auto_update')),
              value: _autoUpdate,
              onChanged: (v) async {
                setState(() => _autoUpdate = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('autoUpdate', v);
              },
            ),
            ElevatedButton.icon(
              onPressed: _checking ? null : _checkUpdate,
              icon: _checking
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update_alt, size: 18),
              label: Text(tr(context, 'check_update')),
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
