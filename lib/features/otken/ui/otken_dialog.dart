import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/platform/platform_service.dart';

/// Ötken (ex-« Shadow Explorer ») : exploration des snapshots Linux
/// (Btrfs /.snapshots, Timeshift) — navigation lecture seule dans le panneau actif.
class OtkenDialog extends StatefulWidget {
  const OtkenDialog({super.key, required this.onSnapshotSelected});
  final ValueChanged<String> onSnapshotSelected;

  @override
  State<OtkenDialog> createState() => _OtkenDialogState();
}

class _OtkenDialogState extends State<OtkenDialog> {
  List<String> _snapshots = [];

  @override
  void initState() {
    super.initState();
    _detect();
  }

  void _detect() {
    final found = <String>[];
    for (final root in createPlatformService().snapshotRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      try {
        for (final e in dir.listSync()) {
          if (e is Directory) found.add(e.path);
        }
      } catch (_) {}
    }
    setState(() => _snapshots = found);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'otken_title')),
      content: SizedBox(
        width: 420,
        height: 300,
        child: _snapshots.isEmpty
            ? Center(child: Text(tr(context, 'no_snapshots'), textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: _snapshots.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF2DD4BF)),
                  title: Text(_snapshots[i].split(Platform.pathSeparator).last),
                  subtitle: Text(_snapshots[i],
                      style: const TextStyle(fontSize: 10)),
                  onTap: () {
                    widget.onSnapshotSelected(_snapshots[i]);
                    Navigator.pop(context);
                  },
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
