import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/file_entry.dart';

enum SortBy { name, size, date }
enum ViewMode { list, grid }

class FileSystemService {
  /// Listing + stats EN PARALLÈLE + filtre cachés + tri.
  Future<List<FileEntry>> listDirectory(
    String dir, {
    bool showHidden = false,
    SortBy sortBy = SortBy.name,
    bool ascending = true,
  }) async {
    final entities = await Directory(dir).list(followLinks: false).toList();
    final stats = await Future.wait(entities.map((e) async {
      try {
        return await e.stat();
      } catch (_) {
        return null;
      }
    }));
    final entries = <FileEntry>[];
    for (var i = 0; i < entities.length; i++) {
      final st = stats[i];
      if (st == null) continue;
      final entry = FileEntry(
        path: entities[i].path,
        stat: st,
        isDir: entities[i] is Directory,
      );
      if (!showHidden && entry.isHidden) continue;
      entries.add(entry);
    }
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      int comp;
      switch (sortBy) {
        case SortBy.size:
          comp = a.size.compareTo(b.size);
        case SortBy.date:
          comp = a.modified.compareTo(b.modified);
        case SortBy.name:
        default:
          comp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return ascending ? comp : -comp;
    });
    return entries;
  }

  /// Ouverture externe GARANTIE : xdg-open -> gio -> gnome-open -> kde-open
  /// (Linux), cmd start (Windows). Processus détaché.
  Future<void> openExternal(String path) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', '"$path"'],
          mode: ProcessStartMode.detached);
      return;
    }
    for (final cmd in [
      ['xdg-open', path],
      ['gio', 'open', path],
      ['gnome-open', path],
      ['kde-open', path],
    ]) {
      try {
        await Process.start(cmd[0], cmd.sublist(1),
            mode: ProcessStartMode.detached);
        return;
      } catch (_) {}
    }
  }

  Future<void> copyEntity(String src, String destDir) async {
    final dest = p.join(destDir, p.basename(src));
    if (FileSystemEntity.isDirectorySync(src)) {
      await _copyDir(Directory(src), Directory(dest));
    } else {
      await File(src).copy(dest);
    }
  }

  Future<void> _copyDir(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final e in src.list(followLinks: false)) {
      final target = p.join(dest.path, p.basename(e.path));
      if (e is Directory) {
        await _copyDir(e, Directory(target));
      } else {
        await File(e.path).copy(target);
      }
    }
  }

  /// Déplacement : méthodes d'instance (File.rename / Directory.rename).
  Future<void> moveEntity(String src, String destDir) async {
    final dest = p.join(destDir, p.basename(src));
    if (FileSystemEntity.isDirectorySync(src)) {
      await Directory(src).rename(dest);
    } else {
      await File(src).rename(dest);
    }
  }

  /// Renommage : méthodes d'instance (File.rename / Directory.rename).
  Future<void> renameEntity(String path, String newName) async {
    final dest = p.join(p.dirname(path), newName);
    if (FileSystemEntity.isDirectorySync(path)) {
      await Directory(path).rename(dest);
    } else {
      await File(path).rename(dest);
    }
  }

  /// Suppression : méthodes d'instance (File.delete / Directory.delete).
  Future<void> deleteEntity(String path) async {
    if (FileSystemEntity.isDirectorySync(path)) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<void> createFolder(String dir, String name) async {
    await Directory(p.join(dir, name)).create(recursive: true);
  }
}
