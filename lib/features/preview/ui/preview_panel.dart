import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/utils/file_utils.dart';
import '../../files/data/models/file_entry.dart';
import '../../files/state/pane_controller.dart';
import '../services/office_service.dart';
import '../services/thumb_service.dart';

const _imageExts = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.ico'];
const _textExts = [
  '.txt', '.md', '.log', '.json', '.yaml', '.yml', '.dart', '.py', '.js',
  '.ts', '.html', '.css', '.xml', '.csv', '.sh', '.bat', '.c', '.cpp',
  '.h', '.rs', '.ini', '.conf',
];
const _videoExts = ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv'];
const _audioExts = ['.mp3', '.wav', '.ogg', '.flac', '.m4a', '.aac'];
const _archiveExts = ['.zip', '.tar', '.gz', '.bz2', '.xz'];

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key, required this.controller});

  final PaneController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final e = controller.selected;
        return SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: e == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(tr(context, 'select_file'),
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      SizedBox(height: 260, child: _preview(context, e)),
                      const SizedBox(height: 8),
                      _metaCard(context, e),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ---------- VRAIS APERÇUS ----------
  Widget _preview(BuildContext context, FileEntry e) {
    final ext = e.extension;
    if (e.isDir) {
      return _centerIcon(context, Icons.folder, const Color(0xFFFFB74D), e.name);
    }
    if (_imageExts.contains(ext)) {
      return Image.file(
        File(e.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            _centerIcon(context, Icons.broken_image, Colors.grey, e.name),
      );
    }
    if (ext == '.svg') {
      return SvgPicture.file(
        File(e.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            _centerIcon(context, Icons.broken_image, Colors.grey, e.name),
      );
    }
    if (ext == '.pdf') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PdfViewer.file(e.path),
      );
    }
    if (_textExts.contains(ext)) return _TextPreview(path: e.path);
    // Office : conversion LibreOffice headless -> PDF -> rendu réel
    if (OfficeService.exts.contains(ext)) {
      return FutureBuilder<String?>(
        future: OfficeService.toPdf(e.path, e.modified),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(tr(context, 'office_wait'),
                    style: const TextStyle(fontSize: 11)),
              ],
            );
          }
          if (snap.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PdfViewer.file(snap.data!),
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _centerIcon(context, Icons.article, const Color(0xFF42A5F5), e.name),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(tr(context, 'office_missing'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          );
        },
      );
    }
    if (_videoExts.contains(ext)) {
      return FutureBuilder<String?>(
        future: ThumbService.videoThumb(e.path),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data != null) {
            return Image.file(File(snap.data!), fit: BoxFit.contain);
          }
          return _centerIcon(context, Icons.movie, const Color(0xFFEF5350), e.name);
        },
      );
    }
    if (_audioExts.contains(ext)) {
      return FutureBuilder<String?>(
        future: ThumbService.audioCover(e.path),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data != null) {
            return Image.file(File(snap.data!), fit: BoxFit.contain);
          }
          return _centerIcon(context, Icons.audiotrack, const Color(0xFFAB47BC), e.name);
        },
      );
    }
    if (_archiveExts.contains(ext)) {
      return FutureBuilder<List<String>>(
        future: ThumbService.archiveEntries(e.path),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final names = snap.data ?? const [];
          if (names.isEmpty) {
            return _centerIcon(context, Icons.folder_zip, const Color(0xFFFFA726), e.name);
          }
          return ListView.builder(
            itemCount: names.length,
            itemBuilder: (_, i) => Text(
              names[i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          );
        },
      );
    }
    // Repli « réel » : vue hexadécimale (binaires, .exe, .dll, .dat...)
    return _HexPreview(path: e.path);
  }

  Widget _centerIcon(BuildContext context, IconData icon, Color color, String name) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );

  // ---------- Métadonnées (UN seul deux-points) ----------
  Widget _metaCard(BuildContext context, FileEntry e) {
    final locale = Localizations.localeOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, 'details'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            _row(context, 'name', e.name),
            _row(context, 'path', e.path),
            if (!e.isDir) _row(context, 'size', formatSize(e.size, locale)),
            _row(context, 'modified', formatDate(e.modified)),
            _row(context, 'accessed', formatDate(e.accessed)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SelectableText(
          '${tr(context, key)} $value',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      );
}

// ---------- Texte avec numéros de lignes ----------
class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: File(path).openRead(0, 512 * 1024).first.catchError((_) => <int>[]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = utf8.decode(snap.data ?? const [], allowMalformed: true);
        final lines = text.split('\n');
        return ListView.builder(
          itemCount: lines.length,
          itemBuilder: (_, i) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${i + 1}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  lines[i],
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Vue hexadécimale (binaires) ----------
class _HexPreview extends StatelessWidget {
  const _HexPreview({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: File(path).openRead(0, 1024).first.catchError((_) => <int>[]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snap.data ?? const <int>[];
        final sb = StringBuffer();
        for (var i = 0; i < bytes.length; i += 16) {
          final chunk = bytes.skip(i).take(16).toList();
          final hex =
              chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          final ascii = chunk
              .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
              .join();
          sb.writeln('${i.toRadixString(16).padLeft(8, '0')}  $hex  $ascii');
        }
        return SingleChildScrollView(
          child: SelectableText(
            sb.toString(),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        );
      },
    );
  }
}
