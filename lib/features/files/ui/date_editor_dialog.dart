import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/platform/windows_times.dart';

/// Éditeur de dates :
/// - Modifié + Accédé : modifiables sur Linux ET Windows.
/// - Créé : modifiable sous WINDOWS (Win32 SetFileTime) ;
///   lecture seule sous Linux (le noyau n'expose aucune API pour btime),
///   avec bandeau d'information professionnel et vraie date de naissance
///   affichée (stat -c %W).
class DateEditorDialog extends StatefulWidget {
  const DateEditorDialog({super.key, required this.path});
  final String path;

  @override
  State<DateEditorDialog> createState() => _DateEditorDialogState();
}

class _DateEditorDialogState extends State<DateEditorDialog> {
  late DateTime _modified;
  late DateTime _accessed;
  DateTime? _created;

  @override
  void initState() {
    super.initState();
    final stat = File(widget.path).statSync();
    _modified = stat.modified;
    _accessed = stat.accessed;
    _loadCreated();
  }

  Future<void> _loadCreated() async {
    if (Platform.isWindows) {
      final c = WindowsTimes.getCreation(widget.path);
      if (mounted) setState(() => _created = c);
    } else {
      final c = await _linuxBirth();
      if (mounted) setState(() => _created = c);
    }
  }

  /// Vraie date de naissance Linux via `stat -c %W` (0/- = inconnue).
  Future<DateTime?> _linuxBirth() async {
    try {
      final r = await Process.run('stat', ['-c', '%W', widget.path]);
      final secs = int.tryParse((r.stdout as String).trim());
      if (secs != null && secs > 0) {
        return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pick(DateTime current, void Function(DateTime) set) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(() =>
        set(DateTime(date.year, date.month, date.day, time.hour, time.minute)));
  }

  Future<void> _save() async {
    try {
      if (Platform.isWindows) {
        await WindowsTimes.setTimes(
          widget.path,
          created: _created,
          accessed: _accessed,
          modified: _modified,
        );
      } else {
        await File(widget.path).setLastModified(_modified);
        await Process.run(
            'touch', ['-a', '-d', _accessed.toIso8601String(), widget.path]);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  /// Bandeau d'information professionnel (Linux uniquement).
  Widget _linuxNotice(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(context, 'created_note'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );

  Widget _row(
    String label,
    DateTime? value, {
    VoidCallback? onEdit,
    String? lockTooltip,
  }) =>
      ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(value == null ? '—' : value.toString().split('.').first),
        trailing: onEdit != null
            ? IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: onEdit,
              )
            : Tooltip(
                message: lockTooltip ?? '',
                child: const Icon(Icons.lock, size: 16),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final createdEditable = Platform.isWindows;
    return AlertDialog(
      title: Text(tr(context, 'edit_dates')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!createdEditable) _linuxNotice(context),
            _row(
              tr(context, 'created'),
              _created,
              onEdit: createdEditable
                  ? () => _pick(_created ?? DateTime.now(), (d) => _created = d)
                  : null,
              lockTooltip: createdEditable ? null : tr(context, 'created_note'),
            ),
            _row(tr(context, 'modified'), _modified,
                onEdit: () => _pick(_modified, (d) => _modified = d)),
            _row(tr(context, 'accessed'), _accessed,
                onEdit: () => _pick(_accessed, (d) => _accessed = d)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
        ElevatedButton(onPressed: _save, child: Text(tr(context, 'save'))),
      ],
    );
  }
}
