import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/platform/platform_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../data/models/file_entry.dart';
import '../../data/services/file_system_service.dart';
import '../../state/pane_controller.dart';

/// Icône + couleur selon le type de fichier.
({IconData icon, Color color}) iconForEntry(FileEntry e) {
  if (e.isDir) return (icon: Icons.folder, color: const Color(0xFFFFB74D));
  switch (e.extension) {
    case '.png': case '.jpg': case '.jpeg': case '.gif':
    case '.webp': case '.bmp': case '.ico': case '.svg':
      return (icon: Icons.image, color: const Color(0xFFFF7043));
    case '.mp4': case '.mkv': case '.avi': case '.mov':
    case '.webm': case '.flv':
      return (icon: Icons.movie, color: const Color(0xFFEF5350));
    case '.mp3': case '.wav': case '.ogg': case '.flac':
    case '.m4a': case '.aac':
      return (icon: Icons.audiotrack, color: const Color(0xFFAB47BC));
    case '.pdf':
      return (icon: Icons.picture_as_pdf, color: const Color(0xFFE53935));
    case '.txt': case '.md': case '.log':
      return (icon: Icons.description, color: const Color(0xFF81D4FA));
    case '.doc': case '.docx': case '.odt':
      return (icon: Icons.article, color: const Color(0xFF42A5F5));
    case '.xls': case '.xlsx': case '.ods': case '.csv':
      return (icon: Icons.table_chart, color: const Color(0xFF66BB6A));
    case '.zip': case '.tar': case '.gz': case '.bz2':
    case '.xz': case '.7z': case '.rar':
      return (icon: Icons.folder_zip, color: const Color(0xFFFFA726));
    case '.dart': case '.py': case '.js': case '.ts': case '.html':
    case '.css': case '.json': case '.yaml': case '.yml': case '.xml':
    case '.c': case '.cpp': case '.h': case '.rs': case '.sh':
      return (icon: Icons.code, color: const Color(0xFF4DB6AC));
    case '.exe': case '.bin': case '.app': case '.deb':
    case '.rpm': case '.flatpak':
      return (icon: Icons.terminal, color: const Color(0xFF4FC3F7));
    default:
      return (icon: Icons.insert_drive_file, color: const Color(0xFF90A4AE));
  }
}

class FilePane extends StatefulWidget {
  const FilePane({
    super.key,
    required this.controller,
    required this.active,
    required this.onActivate,
    required this.onOpen,
    required this.onAction,
    required this.onNewFolder,
    required this.onQuickFolder,
    required this.locale,
  });

  final PaneController controller;
  final bool active;
  final VoidCallback onActivate;
  final void Function(FileEntry) onOpen;
  final void Function(String action, FileEntry entry) onAction;
  final VoidCallback onNewFolder;
  final ValueChanged<QuickFolder> onQuickFolder;
  final Locale locale;

  @override
  State<FilePane> createState() => _FilePaneState();
}

class _FilePaneState extends State<FilePane> {
  final _pathCtl = TextEditingController();
  final _pathFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _pathCtl.text = widget.controller.currentPath;
    widget.controller.addListener(_syncPath);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPath);
    _pathCtl.dispose();
    _pathFocus.dispose();
    super.dispose();
  }

  void _syncPath() {
    if (!_pathFocus.hasFocus &&
        _pathCtl.text != widget.controller.currentPath) {
      _pathCtl.text = widget.controller.currentPath;
    }
  }

  void _showMenu(BuildContext context, Offset pos, FileEntry entry) {
    final multi = widget.controller.selection.length > 1;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem(value: 'open', child: Text(tr(context, 'open'))),
        if (!entry.isDir && (Platform.isWindows || Platform.isLinux))
          PopupMenuItem(
              value: 'open_with', child: Text(tr(context, 'open_with'))),
        PopupMenuItem(value: 'copy', child: Text(tr(context, 'copy'))),
        PopupMenuItem(value: 'cut', child: Text(tr(context, 'cut'))),
        PopupMenuItem(value: 'paste', child: Text(tr(context, 'paste'))),
        PopupMenuItem(value: 'send_to', child: Text(tr(context, 'send_to'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'rename', child: Text(tr(context, 'rename'))),
        if (multi)
          PopupMenuItem(
              value: 'batch_rename', child: Text(tr(context, 'batch_rename'))),
        PopupMenuItem(value: 'delete', child: Text(tr(context, 'delete'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'compress', child: Text(tr(context, 'compress'))),
        if (!entry.isDir &&
            const {
              '.zip',
              '.cbz',
              '.tar',
              '.tar.gz',
              '.tgz',
              '.tar.bz2',
              '.tbz',
              '.tbz2',
              '.tar.xz',
              '.txz',
              '.gz',
              '.bz2',
              '.xz',
            }.any(entry.path.toLowerCase().endsWith))
          PopupMenuItem(value: 'extract', child: Text(tr(context, 'extract_here'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'newfolder', child: Text(tr(context, 'new_folder'))),
        PopupMenuItem(value: 'props', child: Text(tr(context, 'properties'))),
      ],
    ).then((action) {
      if (action != null) widget.onAction(action, entry);
    });
  }

  Widget _tile(BuildContext context, FileEntry entry) {
    final selected = widget.controller.selection.contains(entry.path);
    final primary = widget.controller.selected?.path == entry.path;
    final ic = iconForEntry(entry);
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        widget.onActivate();
        final kb = HardwareKeyboard.instance;
        if (kb.isControlPressed) {
          widget.controller.toggleSelect(entry.path);
        } else if (kb.isShiftPressed && widget.controller.selected != null) {
          widget.controller
              .rangeSelect(widget.controller.selected!.path, entry.path);
        } else {
          widget.controller.selectOnly(entry);
        }
      },
      onDoubleTap: () {
        widget.onActivate();
        widget.onOpen(entry);
      },
      onSecondaryTapUp: (d) {
        widget.onActivate();
        if (!widget.controller.selection.contains(entry.path)) {
          widget.controller.selectOnly(entry);
        }
        _showMenu(context, d.globalPosition, entry);
      },
      child: Container(
        color: primary
            ? scheme.primary.withOpacity(0.25)
            : (selected ? scheme.primary.withOpacity(0.12) : null),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(ic.icon, size: 20, color: entry.isHidden ? Colors.grey : ic.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: entry.isHidden ? Colors.grey : null,
                  fontWeight: entry.isDir ? FontWeight.bold : null,
                ),
              ),
            ),
            if (!entry.isDir)
              SizedBox(
                width: 70,
                child: Text(formatSize(entry.size, widget.locale),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11)),
              ),
            SizedBox(
              width: 110,
              child: Text(formatDate(entry.modified),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridItem(BuildContext context, FileEntry entry) {
    final selected = widget.controller.selection.contains(entry.path);
    final primary = widget.controller.selected?.path == entry.path;
    final ic = iconForEntry(entry);
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        widget.onActivate();
        final kb = HardwareKeyboard.instance;
        if (kb.isControlPressed) {
          widget.controller.toggleSelect(entry.path);
        } else if (kb.isShiftPressed && widget.controller.selected != null) {
          widget.controller
              .rangeSelect(widget.controller.selected!.path, entry.path);
        } else {
          widget.controller.selectOnly(entry);
        }
      },
      onDoubleTap: () {
        widget.onActivate();
        widget.onOpen(entry);
      },
      onSecondaryTapUp: (d) {
        widget.onActivate();
        if (!widget.controller.selection.contains(entry.path)) {
          widget.controller.selectOnly(entry);
        }
        _showMenu(context, d.globalPosition, entry);
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: primary
              ? scheme.primary.withOpacity(0.25)
              : (selected ? scheme.primary.withOpacity(0.12) : scheme.surfaceContainerHighest.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic.icon, size: 40, color: entry.isHidden ? Colors.grey : ic.color),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                entry.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: entry.isHidden ? Colors.grey : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) =>
      SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: Icon(icon, size: 18),
          onPressed: onPressed,
        ),
      );

  Widget _navigationButtons(BuildContext context, PaneController controller) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _compactButton(
            tooltip: '<-',
            icon: Icons.arrow_back,
            onPressed: controller.canGoBack ? controller.back : null,
          ),
          _compactButton(
            tooltip: '->',
            icon: Icons.arrow_forward,
            onPressed: controller.canGoForward ? controller.forward : null,
          ),
          _compactButton(
            tooltip: '..',
            icon: Icons.arrow_upward,
            onPressed: controller.goUp,
          ),
          _compactButton(
            tooltip: tr(context, 'refresh'),
            icon: Icons.refresh,
            onPressed: controller.refresh,
          ),
        ],
      );

  Widget _pathField(PaneController controller) => Expanded(
        child: TextField(
          controller: _pathCtl,
          focusNode: _pathFocus,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: PopupMenuButton<QuickFolder>(
              tooltip: tr(context, 'quick_folders'),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.folder_special, size: 18),
              onSelected: widget.onQuickFolder,
              itemBuilder: (context) => [
                for (final folder in QuickFolder.values)
                  PopupMenuItem(
                    value: folder,
                    child: Row(
                      children: [
                        Icon(_quickFolderIcon(folder), size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, folder.localizationKey)),
                      ],
                    ),
                  ),
              ],
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => controller.cd(value),
        ),
      );

  Widget _actionButtons(BuildContext context, PaneController controller) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _compactButton(
            tooltip: tr(context, 'new_folder'),
            icon: Icons.create_new_folder,
            onPressed: widget.onNewFolder,
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: PopupMenuButton<SortBy>(
              tooltip: tr(context, 'sort_name'),
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: controller.setSort,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: SortBy.name,
                  child: Text(tr(context, 'sort_name')),
                ),
                PopupMenuItem(
                  value: SortBy.size,
                  child: Text(tr(context, 'sort_size')),
                ),
                PopupMenuItem(
                  value: SortBy.date,
                  child: Text(tr(context, 'sort_date')),
                ),
              ],
              icon: const Icon(Icons.sort),
            ),
          ),
          _compactButton(
            tooltip: tr(context, 'view_mode'),
            icon: controller.viewMode == ViewMode.list
                ? Icons.grid_view
                : Icons.view_list,
            onPressed: () => controller.setViewMode(
              controller.viewMode == ViewMode.list
                  ? ViewMode.grid
                  : ViewMode.list,
            ),
          ),
        ],
      );

  Widget _toolbar(BuildContext context, PaneController controller) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final navigation = _navigationButtons(context, controller);
          final path = _pathField(controller);
          final actions = _actionButtons(context, controller);
          if (constraints.maxWidth < 420) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [navigation, path]),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(children: [navigation, path, actions]);
        },
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.controller;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.active ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            color: scheme.surfaceContainerHighest
                .withOpacity(widget.active ? 0.6 : 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _toolbar(context, c),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (c.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        '${tr(context, 'folder_access_failed')}\n${c.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (c.entries.isEmpty) {
                  return const Center(child: Icon(Icons.folder_open, size: 48));
                }
                if (c.viewMode == ViewMode.grid) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: c.entries.length,
                    itemBuilder: (context, i) => _gridItem(context, c.entries[i]),
                  );
                }
                return ListView.builder(
                  itemCount: c.entries.length,
                  itemBuilder: (context, i) => _tile(context, c.entries[i]),
                );
              },
            ),
          ),
            ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.entries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${c.selection.length} ${tr(context, 'selected')} · '
                    '${tr(context, 'selection_hint')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

IconData _quickFolderIcon(QuickFolder folder) => switch (folder) {
      QuickFolder.desktop => Icons.desktop_windows,
      QuickFolder.downloads => Icons.download,
      QuickFolder.videos => Icons.video_library,
      QuickFolder.pictures => Icons.image,
      QuickFolder.documents => Icons.description,
      QuickFolder.music => Icons.music_note,
    };
