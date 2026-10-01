import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/utils/file_utils.dart';
import '../data/models/file_entry.dart';

Future<String?> askArchiveName(BuildContext context, String initialName) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ArchiveNameDialog(initialName: initialName),
    );

class _ArchiveNameDialog extends StatefulWidget {
  const _ArchiveNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_ArchiveNameDialog> createState() => _ArchiveNameDialogState();
}

class _ArchiveNameDialogState extends State<_ArchiveNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr(context, 'compress')),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr(context, 'archive_name'),
            suffixText: '.zip',
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: Text(tr(context, 'create')),
          ),
        ],
      );

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name == '.' ||
        name == '..') {
      return;
    }
    Navigator.pop(context, name);
  }
}

Future<String?> askRename(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) {
        final c = TextEditingController(text: current);
        return AlertDialog(
          title: Text(tr(context, 'rename')),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, c.text),
                child: Text(tr(context, 'save'))),
          ],
        );
      },
    );

Future<String?> askNewFolder(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(tr(context, 'new_folder')),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(labelText: tr(context, 'folder_name')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, c.text),
                child: Text(tr(context, 'create'))),
          ],
        );
      },
    );

Future<bool> confirmDelete(BuildContext context, String name) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'confirm_delete')),
      content: Text('${tr(context, 'confirm_delete_msg')}\n$name'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel'))),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'delete'))),
      ],
    ),
  );
  return r ?? false;
}

Future<void> showProperties(BuildContext context, FileEntry e) => showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'properties')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('${tr(context, 'name')} ${e.name}'),
              SelectableText('${tr(context, 'path')} ${e.path}'),
              if (!e.isDir)
                SelectableText(
                    '${tr(context, 'size')} ${formatSize(e.size, Localizations.localeOf(context))}'),
              SelectableText('${tr(context, 'modified')} ${formatDate(e.modified)}'),
              SelectableText('${tr(context, 'accessed')} ${formatDate(e.accessed)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'cancel'))),
        ],
      ),
    );
