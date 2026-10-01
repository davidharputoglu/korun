import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/app_info.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/platform/platform_service.dart';
import '../../../core/settings/settings_controller.dart';
import '../../otken/ui/otken_dialog.dart';
import '../../preview/ui/preview_panel.dart';
import '../../settings/ui/about_dialog.dart';
import '../../settings/ui/settings_dialog.dart';
import '../../settings/ui/theme_dialog.dart';
import '../data/models/file_entry.dart';
import '../data/services/file_system_service.dart';
import '../state/pane_controller.dart';
import 'batch_rename_dialog.dart';
import 'date_editor_dialog.dart';
import 'file_dialogs.dart';
import 'widgets/file_pane.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _fs = FileSystemService();
  final _platform = createPlatformService();
  late final PaneController _left;
  late final PaneController _right;
  int _activePane = 0;
  List<String> _clipPaths = const [];
  bool _isCut = false;

  @override
  void initState() {
    super.initState();
    _left = PaneController(_fs, initialPath: _platform.homePath);
    _right = PaneController(_fs, initialPath: _platform.homePath);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadBoth());
  }

  bool get _showHidden => context.read<SettingsController>().showHidden;
  PaneController _pane(int i) => i == 0 ? _left : _right;
  PaneController get _active => _pane(_activePane);

  void _reloadBoth() {
    _left.load(showHidden: _showHidden);
    _right.load(showHidden: _showHidden);
  }

  Future<void> _toggleHidden() async {
    await context.read<SettingsController>().toggleHidden();
    _reloadBoth();
  }

  Future<void> _goQuickFolder(
    PaneController pane,
    QuickFolder folder,
  ) async {
    final path = await _platform.getQuickFolderPath(folder);
    if (path == null) {
      if (mounted) {
        _showOperationMessage(
          '${tr(context, folder.localizationKey)}: '
          '${tr(context, 'quick_folder_not_found')}',
        );
      }
      return;
    }
    await pane.cd(path);
  }

  Future<void> _open(FileEntry entry, PaneController pane) async {
    if (entry.isDir) {
      await pane.cd(entry.path);
    } else {
      await _fs.openExternal(entry.path);
    }
  }

  Future<void> _openWith(FileEntry entry) async {
    try {
      if (Platform.isWindows) {
        await _fs.openWith(entry.path);
        return;
      }
      final apps = await _fs.availableOpenWithApps(
        entry.path,
        locale: context.read<SettingsController>().locale.languageCode,
      );
      if (!mounted) return;
      if (apps.isEmpty) {
        _showOperationMessage(tr(context, 'no_open_with_apps'));
        return;
      }
      final app = await showDialog<OpenWithApp>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(tr(dialogContext, 'open_with')),
          children: [
            for (final candidate in apps)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, candidate),
                child: Text(candidate.name),
              ),
          ],
        ),
      );
      if (app != null) await _fs.launchWith(app, entry.path);
    } catch (error) {
      if (mounted) _showOperationMessage(
        '${tr(context, 'open_with_failed')}: $error',
      );
    }
  }

  Future<void> _compress(PaneController pane) async {
    final entries = pane.selectedEntries;
    if (entries.isEmpty) return;
    final initialName = entries.length == 1
        ? p.basenameWithoutExtension(entries.first.name)
        : 'archive';
    final name = await askArchiveName(context, initialName);
    if (name == null) return;
    final archiveName = name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
    try {
      final archivePath = await _fs.compressToZip(
        entries.map((entry) => entry.path).toList(),
        p.join(pane.currentPath, archiveName),
      );
      await pane.refresh();
      if (mounted) _showOperationMessage(
        '${tr(context, 'archive_created')}: ${p.basename(archivePath)}',
      );
    } catch (error) {
      if (mounted) _showOperationMessage('${tr(context, 'operation_failed')}: $error');
    }
  }

  Future<void> _extract(FileEntry entry, PaneController pane) async {
    try {
      final outputPath = await _fs.extractZip(entry.path);
      await pane.refresh();
      if (mounted) _showOperationMessage(
        '${tr(context, 'archive_extracted')}: ${p.basename(outputPath)}',
      );
    } catch (error) {
      if (mounted) _showOperationMessage('${tr(context, 'operation_failed')}: $error');
    }
  }

  void _showOperationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _paste(PaneController pane) async {
    if (_clipPaths.isEmpty) return;
    final total = _clipPaths.length;
    final failures = <String>[];
    var completed = 0;
    for (final src in _clipPaths) {
      try {
        if (_isCut) {
          await _fs.moveEntity(src, pane.currentPath);
        } else {
          await _fs.copyEntity(src, pane.currentPath);
        }
        completed++;
      } catch (error) {
        failures.add('${p.basename(src)}: $error');
      }
    }
    if (_isCut && failures.isEmpty) _clipPaths = const [];
    _reloadBoth();
    if (failures.isNotEmpty) {
      _showOperationMessage(
        '${tr(context, 'operation_failed')} ($completed/$total)\n'
        '${failures.take(3).join('\n')}',
      );
    }
  }

  Future<void> _delete(PaneController pane) async {
    final entries = pane.selectedEntries;
    if (entries.isEmpty) return;
    final label = entries.length == 1
        ? entries.first.name
        : '${entries.length} éléments';
    final ok = await confirmDelete(context, label);
    if (!ok) return;
    final failures = <String>[];
    var deleted = 0;
    for (final e in entries) {
      try {
        await _fs.deleteEntity(e.path);
        deleted++;
      } catch (error) {
        failures.add('${e.name}: $error');
      }
    }
    pane.clearSelection();
    _reloadBoth();
    if (failures.isNotEmpty) {
      _showOperationMessage(
        '${tr(context, 'delete_result')}: $deleted/${entries.length}\n'
        '${failures.take(3).join('\n')}',
      );
    }
  }

  Future<void> _rename(PaneController pane, FileEntry e) async {
    final newName = await askRename(context, e.name);
    if (newName == null || newName.isEmpty || newName == e.name) return;
    try {
      await _fs.renameEntity(e.path, newName);
      _reloadBoth();
    } catch (error) {
      _showOperationMessage('${tr(context, 'operation_failed')}: $error');
    }
  }

  Future<void> _batchRename(PaneController pane) async {
    final entries = pane.selectedEntries;
    if (entries.length < 2) return;
    final newNames = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          BatchRenameDialog(names: entries.map((e) => e.name).toList()),
    );
    if (newNames == null) return;
    final failures = <String>[];
    for (var i = 0; i < entries.length && i < newNames.length; i++) {
      final n = newNames[i];
      if (n.isEmpty || n == entries[i].name) continue;
      try {
        await _fs.renameEntity(entries[i].path, n);
      } catch (error) {
        failures.add('${entries[i].name}: $error');
      }
    }
    _reloadBoth();
    if (failures.isNotEmpty) {
      _showOperationMessage(
        '${tr(context, 'batch_rename')}: ${failures.take(3).join('\n')}',
      );
    }
  }

  Future<void> _newFolder(PaneController pane) async {
    final name = await askNewFolder(context);
    if (name == null || name.isEmpty) return;
    try {
      await _fs.createFolder(pane.currentPath, name);
      await pane.refresh();
    } catch (error) {
      _showOperationMessage('${tr(context, 'operation_failed')}: $error');
    }
  }

  void _onAction(int paneIdx, String action, FileEntry entry) {
    final pane = _pane(paneIdx);
    final other = _pane(paneIdx == 0 ? 1 : 0);
    switch (action) {
      case 'open':
        _open(entry, pane);
      case 'open_with':
        _openWith(entry);
      case 'compress':
        _compress(pane);
      case 'extract':
        _extract(entry, pane);
      case 'copy':
        _clipPaths = pane.selectedEntries.map((e) => e.path).toList();
        _isCut = false;
      case 'cut':
        _clipPaths = pane.selectedEntries.map((e) => e.path).toList();
        _isCut = true;
      case 'paste':
        _paste(pane);
      case 'rename':
        _rename(pane, entry);
      case 'batch_rename':
        _batchRename(pane);
      case 'delete':
        _delete(pane);
      case 'newfolder':
        _newFolder(pane);
      case 'props':
        showProperties(context, entry);
      case 'copy_other':
        _clipPaths = pane.selectedEntries.map((e) => e.path).toList();
        _isCut = false;
        _paste(other);
      case 'move_other':
        _clipPaths = pane.selectedEntries.map((e) => e.path).toList();
        _isCut = true;
        _paste(other);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyH, control: true):
            _toggleHidden,
        const SingleActivator(LogicalKeyboardKey.tab): () =>
            setState(() => _activePane = _activePane == 0 ? 1 : 0),
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (_active.selected != null) {
            _onAction(_activePane, 'copy_other', _active.selected!);
          }
        },
        const SingleActivator(LogicalKeyboardKey.f6): () {
          if (_active.selected != null) {
            _onAction(_activePane, 'move_other', _active.selected!);
          }
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (_active.selected != null) {
            _rename(_active, _active.selected!);
          }
        },
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _delete(_active),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            _active.selectAll(),
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () =>
            _batchRename(_active),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppInfo.logoAsset, width: 28, height: 28),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(tr(context, 'title'),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('v${AppInfo.version}',
                    style: TextStyle(fontSize: 11, color: scheme.outline)),
              ],
            ),
            actions: [
              if (settings.otkenEnabled)
                IconButton(
                  tooltip: tr(context, 'otken_title'),
                  icon: const Icon(Icons.history),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => OtkenDialog(
                      onSnapshotSelected: (p) => _active.cd(p),
                    ),
                  ),
                ),
              IconButton(
                tooltip: tr(context, 'edit_dates'),
                icon: const Icon(Icons.edit_calendar),
                onPressed: (_active.selected == null || _active.selected!.isDir)
                    ? null
                    : () async {
                        final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => DateEditorDialog(
                              path: _active.selected!.path),
                        );
                        if (saved == true) _reloadBoth();
                      },
              ),
              IconButton(
                tooltip: settings.showHidden
                    ? tr(context, 'hide_hidden')
                    : tr(context, 'show_hidden'),
                icon: Icon(settings.showHidden
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: _toggleHidden,
              ),
              IconButton(
                tooltip: tr(context, 'theme_title'),
                icon: const Icon(Icons.palette),
                onPressed: () => showDialog(
                    context: context, builder: (_) => const ThemeDialog()),
              ),
              PopupMenuButton<String>(
                tooltip: tr(context, 'language_title'),
                icon: const Icon(Icons.language),
                onSelected: (code) => settings.setLocale(Locale(code)),
                itemBuilder: (_) => [
                  for (final e in L10n.nativeNames.entries)
                    PopupMenuItem(value: e.key, child: Text(e.value)),
                ],
              ),
              IconButton(
                tooltip: tr(context, 'settings'),
                icon: const Icon(Icons.settings),
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        SettingsDialog(onShowHiddenChanged: _reloadBoth)),
              ),
              IconButton(
                tooltip: tr(context, 'about'),
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                    context: context, builder: (_) => const KorunAboutDialog()),
              ),
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: FilePane(
                          controller: _left,
                          active: _activePane == 0,
                          locale: settings.locale,
                          onActivate: () => setState(() => _activePane = 0),
                          onOpen: (e) => _open(e, _left),
                          onAction: (a, e) => _onAction(0, a, e),
                          onNewFolder: () => _newFolder(_left),
                          onQuickFolder: (folder) =>
                              _goQuickFolder(_left, folder),
                        ),
                      ),
                      if (settings.showPreviews)
                        PreviewPanel(
                          controller: _left,
                          width: constraints.maxWidth < 640 ? 180 : 240,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: FilePane(
                          controller: _right,
                          active: _activePane == 1,
                          locale: settings.locale,
                          onActivate: () => setState(() => _activePane = 1),
                          onOpen: (e) => _open(e, _right),
                          onAction: (a, e) => _onAction(1, a, e),
                          onNewFolder: () => _newFolder(_right),
                          onQuickFolder: (folder) =>
                              _goQuickFolder(_right, folder),
                        ),
                      ),
                      if (settings.showPreviews)
                        PreviewPanel(
                          controller: _right,
                          width: constraints.maxWidth < 640 ? 180 : 240,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
