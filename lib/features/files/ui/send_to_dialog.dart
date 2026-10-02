import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';

enum SendAction { copy, move, shortcut, email }

class SendToTarget {
  const SendToTarget({
    required this.name,
    required this.path,
    required this.icon,
  });

  final String name;
  final String path;
  final IconData icon;
}

class SendToSelection {
  const SendToSelection(this.action, {this.path});

  final SendAction action;
  final String? path;
}

class SendToDialog extends StatefulWidget {
  const SendToDialog({super.key, required this.targets});

  final List<SendToTarget> targets;

  @override
  State<SendToDialog> createState() => _SendToDialogState();
}

class _SendToDialogState extends State<SendToDialog> {
  SendAction _action = SendAction.copy;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr(context, 'send_to')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<SendAction>(
                segments: [
                  ButtonSegment(
                    value: SendAction.copy,
                    icon: const Icon(Icons.copy),
                    label: Text(tr(context, 'copy_to')),
                  ),
                  ButtonSegment(
                    value: SendAction.move,
                    icon: const Icon(Icons.drive_file_move),
                    label: Text(tr(context, 'move_to')),
                  ),
                ],
                selected: {_action},
                onSelectionChanged: (selection) =>
                    setState(() => _action = selection.first),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final target in widget.targets)
                      ListTile(
                        leading: Icon(target.icon),
                        title: Text(target.name),
                        subtitle: Text(
                          target.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          SendToSelection(_action, path: target.path),
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.folder_open),
                      title: Text(tr(context, 'pick_destination')),
                      onTap: _pickDestination,
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.desktop_windows),
                title: Text(tr(context, 'create_shortcut')),
                onTap: () => Navigator.pop(
                  context,
                  const SendToSelection(SendAction.shortcut),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(tr(context, 'send_by_email')),
                onTap: () => Navigator.pop(
                  context,
                  const SendToSelection(SendAction.email),
                ),
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

  Future<void> _pickDestination() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: tr(context, 'pick_destination'),
    );
    if (path != null && mounted) {
      Navigator.pop(context, SendToSelection(_action, path: path));
    }
  }
}
