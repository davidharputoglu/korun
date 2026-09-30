import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/i18n/l10n.dart';

enum _BatchMode { number, replace, caseMode }

/// Renommage groupé : numérotation, rechercher/remplacer, casse.
/// Aperçu en direct des nouveaux noms avant application.
class BatchRenameDialog extends StatefulWidget {
  const BatchRenameDialog({super.key, required this.names});
  final List<String> names;

  @override
  State<BatchRenameDialog> createState() => _BatchRenameDialogState();
}

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  _BatchMode _mode = _BatchMode.number;
  final _base = TextEditingController(text: 'fichier_');
  final _start = TextEditingController(text: '1');
  final _padding = TextEditingController(text: '3');
  final _search = TextEditingController();
  final _replace = TextEditingController();
  int _case = 0; // 0 = minuscules, 1 = MAJUSCULES

  String _one(String name, int index) {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    switch (_mode) {
      case _BatchMode.number:
        final s = int.tryParse(_start.text) ?? 1;
        final pad = int.tryParse(_padding.text) ?? 3;
        return _base.text + (s + index).toString().padLeft(pad, '0') + ext;
      case _BatchMode.replace:
        if (_search.text.isEmpty) return name;
        return name.replaceAll(_search.text, _replace.text);
      case _BatchMode.caseMode:
        return (_case == 0 ? base.toLowerCase() : base.toUpperCase()) + ext;
    }
  }

  List<String> _compute() =>
      [for (var i = 0; i < widget.names.length; i++) _one(widget.names[i], i)];

  @override
  Widget build(BuildContext context) {
    final preview = _compute();
    return AlertDialog(
      title: Text(tr(context, 'batch_rename')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<_BatchMode>(
              dense: true,
              value: _BatchMode.number,
              groupValue: _mode,
              title: Text(tr(context, 'batch_mode_number')),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode == _BatchMode.number)
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _base,
                    decoration: InputDecoration(labelText: tr(context, 'batch_base')),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _start,
                    decoration: InputDecoration(labelText: tr(context, 'batch_start')),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _padding,
                    decoration: const InputDecoration(labelText: '000'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            RadioListTile<_BatchMode>(
              dense: true,
              value: _BatchMode.replace,
              groupValue: _mode,
              title: Text(tr(context, 'batch_mode_replace')),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode == _BatchMode.replace)
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(labelText: tr(context, 'batch_search')),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _replace,
                    decoration: InputDecoration(labelText: tr(context, 'batch_replace')),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            RadioListTile<_BatchMode>(
              dense: true,
              value: _BatchMode.caseMode,
              groupValue: _mode,
              title: Text(tr(context, 'batch_mode_case')),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode == _BatchMode.caseMode)
              Row(children: [
                ChoiceChip(
                  label: Text(tr(context, 'batch_lower')),
                  selected: _case == 0,
                  onSelected: (_) => setState(() => _case = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(tr(context, 'batch_upper')),
                  selected: _case == 1,
                  onSelected: (_) => setState(() => _case = 1),
                ),
              ]),
            const Divider(),
            Text('${tr(context, 'batch_preview')} (${widget.names.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 140,
              child: ListView.builder(
                itemCount: widget.names.length,
                itemBuilder: (_, i) => Text(
                  '${widget.names[i]}  →  ${preview[i]}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel'))),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, preview),
            child: Text(tr(context, 'save'))),
      ],
    );
  }
}
