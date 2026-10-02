import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/settings/settings_controller.dart';

Future<void> showUserGuide(BuildContext context) async {
  final settings = context.read<SettingsController>();
  final showAgain = await showDialog<bool>(
    context: context,
    builder: (_) => _GuideDialog(
      showAtStartup: settings.showFirstUseGuide,
    ),
  );
  if (showAgain != null) {
    await settings.setShowFirstUseGuide(showAgain);
  }
}

class _GuideDialog extends StatefulWidget {
  const _GuideDialog({required this.showAtStartup});

  final bool showAtStartup;

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  late bool _showAtStartup = widget.showAtStartup;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(tr(context, 'guide_title'))),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'guide_intro')),
                const SizedBox(height: 18),
                _GuideSection(
                  icon: Icons.edit_calendar_outlined,
                  title: tr(context, 'guide_dates_title'),
                  body: tr(context, 'guide_dates_body'),
                ),
                const SizedBox(height: 16),
                _GuideSection(
                  icon: Icons.history,
                  title: tr(context, 'guide_otken_title'),
                  body: tr(context, 'guide_otken_body'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _showAtStartup,
                  onChanged: (value) => setState(
                    () => _showAtStartup = value ?? false,
                  ),
                  title: Text(tr(context, 'guide_show_at_start')),
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, _showAtStartup),
            child: Text(tr(context, 'close')),
          ),
        ],
      );
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(body),
          ),
        ],
      );
}
