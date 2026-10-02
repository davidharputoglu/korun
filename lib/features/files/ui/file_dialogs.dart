import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/utils/file_utils.dart';
import '../data/models/file_entry.dart';
import '../data/services/file_system_service.dart';

class ArchiveCreationRequest {
  const ArchiveCreationRequest({
    required this.name,
    required this.format,
    required this.engine,
  });

  final String name;
  final ArchiveFormat format;
  final CompressionEngine engine;
}

Future<ArchiveCreationRequest?> askArchiveName(
  BuildContext context,
  String initialName, {
  required bool allowStandaloneFormats,
}) =>
    showDialog<ArchiveCreationRequest>(
      context: context,
      builder: (_) => _ArchiveNameDialog(
        initialName: initialName,
        allowStandaloneFormats: allowStandaloneFormats,
      ),
    );

class _ArchiveNameDialog extends StatefulWidget {
  const _ArchiveNameDialog({
    required this.initialName,
    required this.allowStandaloneFormats,
  });

  final String initialName;
  final bool allowStandaloneFormats;

  @override
  State<_ArchiveNameDialog> createState() => _ArchiveNameDialogState();
}

class _ArchiveNameDialogState extends State<_ArchiveNameDialog> {
  late final TextEditingController _controller;
  ArchiveFormat _format = ArchiveFormat.zip;
  CompressionEngine _engine = CompressionEngine.korun;
  bool _checkingArchivers = true;
  final Map<CompressionEngine, String?> _engineExecutables = {
    CompressionEngine.korun: null,
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _detectExternalArchivers();
  }

  Future<void> _detectExternalArchivers() async {
    final results = await Future.wait([
      FileSystemService.findSevenZipExecutable(),
      FileSystemService.findWinRarExecutable(),
    ]);
    if (mounted) {
      setState(() {
        if (results[0] != null) {
          _engineExecutables[CompressionEngine.sevenZip] = results[0];
        }
        if (results[1] != null) {
          _engineExecutables[CompressionEngine.winRar] = results[1];
        }
        if (!_formats.contains(_format)) _format = _formats.first;
        _checkingArchivers = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr(context, 'compress')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr(context, 'archive_name'),
                suffixText: _format.extension,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            if (_engineExecutables.length > 1) ...[
              DropdownButtonFormField<CompressionEngine>(
                value: _engine,
                decoration: InputDecoration(
                  labelText: tr(context, 'compression_method'),
                ),
                items: [
                  for (final engine in _engineExecutables.keys)
                    DropdownMenuItem(
                      value: engine,
                      child: Text(
                        tr(
                          context,
                          switch (engine) {
                            CompressionEngine.korun =>
                              'compression_method_korun',
                            CompressionEngine.sevenZip =>
                              'compression_method_7zip',
                            CompressionEngine.winRar =>
                              'compression_method_winrar',
                          },
                        ),
                      ),
                    ),
                ],
                onChanged: (engine) {
                  if (engine == null) return;
                  setState(() {
                    _engine = engine;
                    if (!_formats.contains(_format)) _format = _formats.first;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<ArchiveFormat>(
              value: _format,
              decoration: InputDecoration(labelText: tr(context, 'archive_format')),
              items: [
                for (final format in _formats)
                  DropdownMenuItem(
                    value: format,
                    child: Text(tr(context, format.localizationKey)),
                  ),
              ],
              onChanged: (format) =>
                  setState(() => _format = format ?? _format),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: _checkingArchivers ? null : _submit,
            child: Text(tr(context, 'create')),
          ),
        ],
      );

  List<ArchiveFormat> get _formats {
    final formats = switch (_engine) {
      CompressionEngine.korun => ArchiveFormat.values
          .where((format) =>
              format != ArchiveFormat.sevenZip && format != ArchiveFormat.rar)
          .toList(),
      CompressionEngine.sevenZip => [
          ArchiveFormat.zip,
          ArchiveFormat.tar,
          ArchiveFormat.sevenZip,
          ArchiveFormat.gzip,
          ArchiveFormat.bzip2,
          ArchiveFormat.xz,
        ],
      CompressionEngine.winRar => [
          ArchiveFormat.rar,
        ],
    };
    if (!widget.allowStandaloneFormats) {
      formats.removeWhere(
        (format) =>
            format == ArchiveFormat.gzip ||
            format == ArchiveFormat.bzip2 ||
            format == ArchiveFormat.xz,
      );
    }
    return formats;
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name == '.' ||
        name == '..') {
      return;
    }
    Navigator.pop(
      context,
      ArchiveCreationRequest(name: name, format: _format, engine: _engine),
    );
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
