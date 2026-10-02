import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';

enum SortBy { name, size, date }
enum ViewMode { list, grid }
enum _ArchiveType { zip, tar, tarGzip, tarBzip2, tarXz }

class OpenWithApp {
  const OpenWithApp({required this.name, required this.desktopFile});

  final String name;
  final String desktopFile;
}

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

  Future<void> openWith(String path) async {
    if (Platform.isWindows) {
      await Process.start(
        'rundll32.exe',
        ['shell32.dll,OpenAs_RunDLL', path],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    throw UnsupportedError(
      'Choose a Linux application with availableOpenWithApps and launchWith.',
    );
  }

  Future<List<OpenWithApp>> availableOpenWithApps(
    String path, {
    required String locale,
  }) async {
    if (!Platform.isLinux) return const [];
    final mimeType = lookupMimeType(path);
    if (mimeType == null) return const [];

    final dataHome = Platform.environment['XDG_DATA_HOME'] ??
        p.join(Platform.environment['HOME'] ?? '', '.local', 'share');
    final dataDirs = (Platform.environment['XDG_DATA_DIRS'] ??
            '/usr/local/share:/usr/share')
        .split(':');
    final applicationDirs = <String>[
      p.join(dataHome, 'applications'),
      ...dataDirs.map((dir) => p.join(dir, 'applications')),
    ];

    final apps = <String, OpenWithApp>{};
    for (final directoryPath in applicationDirs) {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) continue;
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.desktop')) continue;
        final contents = await entity.readAsString();
        final entry = _parseDesktopEntry(contents, locale);
        if (entry == null ||
            !entry.mimeTypes.contains(mimeType) ||
            entry.hidden ||
            entry.noDisplay) {
          continue;
        }
        final name = entry.name;
        apps.putIfAbsent(
          entity.path,
          () => OpenWithApp(name: name, desktopFile: entity.path),
        );
      }
    }
    final result = apps.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> launchWith(OpenWithApp app, String path) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('Desktop file launching is only supported on Linux.');
    }
    await Process.start(
      'gio',
      ['launch', app.desktopFile, p.toUri(path).toString()],
      mode: ProcessStartMode.detached,
    );
  }

  _DesktopEntry? _parseDesktopEntry(String contents, String locale) {
    var inDesktopEntry = false;
    var name = '';
    var localizedName = '';
    var mimeTypes = <String>[];
    var hidden = false;
    var noDisplay = false;
    var type = '';
    final language = locale.split('_').first.split('@').first;
    for (final rawLine in const LineSplitter().convert(contents)) {
      final line = rawLine.trim();
      if (line.startsWith('[') && line.endsWith(']')) {
        inDesktopEntry = line == '[Desktop Entry]';
        continue;
      }
      if (!inDesktopEntry || line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator < 1) continue;
      final key = line.substring(0, separator);
      final value = line.substring(separator + 1);
      if (key == 'Name') name = value;
      if (key == 'Name[$language]') localizedName = value;
      if (key == 'MimeType') mimeTypes = value.split(';');
      if (key == 'Hidden') hidden = value == 'true';
      if (key == 'NoDisplay') noDisplay = value == 'true';
      if (key == 'Type') type = value;
    }
    if (type != 'Application' || name.isEmpty) return null;
    return _DesktopEntry(
      name: localizedName.isEmpty ? name : localizedName,
      mimeTypes: mimeTypes,
      hidden: hidden,
      noDisplay: noDisplay,
    );
  }

  Future<String> compressToZip(
    List<String> paths,
    String archivePath,
  ) async {
    if (paths.isEmpty) {
      throw ArgumentError('Select at least one file or folder.');
    }
    if (await FileSystemEntity.type(
          archivePath,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('The archive already exists.', archivePath);
    }

    final output = File(archivePath);
    await output.create(exclusive: true);
    OutputFileStream? outputStream;
    final encoder = ZipEncoder();
    try {
      outputStream = OutputFileStream(archivePath);
      encoder.startEncode(outputStream);
      for (final sourcePath in paths) {
        final sourceName = p.basename(sourcePath);
        final type =
            await FileSystemEntity.type(sourcePath, followLinks: false);
        if (type == FileSystemEntityType.file) {
          await _addFileToArchive(encoder, File(sourcePath), sourceName);
        } else if (type == FileSystemEntityType.directory) {
          await _addDirectoryToArchive(
            encoder,
            Directory(sourcePath),
            sourceName,
          );
        } else {
          throw FileSystemException(
            'Unsupported file system entry.',
            sourcePath,
          );
        }
      }
      encoder.endEncode();
      await outputStream.close();
    } catch (_) {
      if (outputStream != null) await outputStream.close();
      await output.delete();
      rethrow;
    }
    return archivePath;
  }

  Future<void> _addDirectoryToArchive(
    ZipEncoder encoder,
    Directory directory,
    String archiveDirectory,
  ) async {
    final children =
        await directory.list(followLinks: false, recursive: false).toList();
    if (children.isEmpty) {
      encoder.add(
        ArchiveFile.directory('$archiveDirectory/'),
        autoClose: false,
      );
      return;
    }
    await _addDirectoryChildren(encoder, children, archiveDirectory);
  }

  Future<void> _addDirectoryChildren(
    ZipEncoder encoder,
    List<FileSystemEntity> children,
    String archiveDirectory,
  ) async {
    for (final entity in children) {
      final name = p.posix.join(archiveDirectory, p.basename(entity.path));
      if (entity is Directory) {
        final nestedChildren =
            await entity.list(followLinks: false, recursive: false).toList();
        if (nestedChildren.isEmpty) {
          encoder.add(ArchiveFile.directory('$name/'), autoClose: false);
        } else {
          await _addDirectoryChildren(encoder, nestedChildren, name);
        }
      } else if (entity is File) {
        await _addFileToArchive(encoder, entity, name);
      }
    }
  }

  Future<void> _addFileToArchive(
    ZipEncoder encoder,
    File file,
    String archivePath,
  ) async {
    final input = InputFileStream(file.path);
    try {
      final archiveFile = ArchiveFile.stream(archivePath, input);
      archiveFile.lastModTime =
          (await file.lastModified()).millisecondsSinceEpoch ~/ 1000;
      encoder.add(archiveFile, autoClose: false);
    } finally {
      await input.close();
    }
  }

  Future<String> extractZip(String archivePath) => extractArchive(archivePath);

  Future<String> extractArchive(String archivePath) async {
    final lowerPath = archivePath.toLowerCase();
    final archiveType = _archiveType(lowerPath);
    if (archiveType == null) {
      throw FileSystemException(
        'Unsupported archive format. Supported: ZIP/CBZ, TAR, TAR.GZ, '
        'TAR.BZ2, and TAR.XZ.',
        archivePath,
      );
    }
    final parentPath = p.dirname(archivePath);
    final archiveName = _archiveBaseName(archivePath, archiveType);
    var outputPath = await _availableExtractionPath(parentPath, archiveName);

    InputFileStream? input;
    Directory? staging;
    try {
      final archive = switch (archiveType) {
        _ArchiveType.zip => () {
            input = InputFileStream(archivePath);
            return ZipDecoder().decodeStream(input!);
          }(),
        _ArchiveType.tar => TarDecoder().decodeBytes(
            File(archivePath).readAsBytesSync(),
          ),
        _ArchiveType.tarGzip => TarDecoder().decodeBytes(
            GZipDecoder().decodeBytes(File(archivePath).readAsBytesSync()),
          ),
        _ArchiveType.tarBzip2 => TarDecoder().decodeBytes(
            BZip2Decoder().decodeBytes(File(archivePath).readAsBytesSync()),
          ),
        _ArchiveType.tarXz => TarDecoder().decodeBytes(
            XZDecoder().decodeBytes(File(archivePath).readAsBytesSync()),
          ),
      };
      staging =
          await Directory(parentPath).createTemp('.korun-extract-');
      for (final entry in archive) {
        final normalizedName = entry.name.replaceAll('\\', '/');
        final segments = normalizedName.split('/');
        if (normalizedName.startsWith('/') ||
            RegExp(r'^[a-zA-Z]:').hasMatch(normalizedName) ||
            segments.contains('..') ||
            entry.isSymbolicLink) {
          throw FormatException('Unsafe path in archive: ${entry.name}');
        }
        if (normalizedName.isEmpty || normalizedName == '.') continue;
        final destination = p.normalize(p.join(staging.path, normalizedName));
        if (!p.isWithin(staging.path, destination)) {
          throw FormatException('Unsafe path in archive: ${entry.name}');
        }
        if (entry.isDirectory) {
          await Directory(destination).create(recursive: true);
        } else if (entry.isFile) {
          if (await FileSystemEntity.type(
                destination,
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound) {
            throw FormatException(
              'Duplicate path in archive: ${entry.name}',
            );
          }
          await Directory(p.dirname(destination)).create(recursive: true);
          final output = OutputFileStream(destination);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }
        } else {
          throw FormatException(
            'Unsupported special entry in archive: ${entry.name}',
          );
        }
      }
      outputPath = await _availableExtractionPath(parentPath, archiveName);
      await staging.rename(outputPath);
    } catch (_) {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    } finally {
      await input?.close();
    }
    return outputPath;
  }

  _ArchiveType? _archiveType(String lowerPath) {
    if (lowerPath.endsWith('.zip') || lowerPath.endsWith('.cbz')) {
      return _ArchiveType.zip;
    }
    if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
      return _ArchiveType.tarGzip;
    }
    if (lowerPath.endsWith('.tar.bz2') ||
        lowerPath.endsWith('.tbz') ||
        lowerPath.endsWith('.tbz2')) {
      return _ArchiveType.tarBzip2;
    }
    if (lowerPath.endsWith('.tar.xz') || lowerPath.endsWith('.txz')) {
      return _ArchiveType.tarXz;
    }
    if (lowerPath.endsWith('.tar')) return _ArchiveType.tar;
    return null;
  }

  String _archiveBaseName(String archivePath, _ArchiveType type) {
    final name = p.basename(archivePath);
    final suffix = switch (type) {
      _ArchiveType.zip => name.toLowerCase().endsWith('.cbz') ? '.cbz' : '.zip',
      _ArchiveType.tar => '.tar',
      _ArchiveType.tarGzip =>
        name.toLowerCase().endsWith('.tgz') ? '.tgz' : '.tar.gz',
      _ArchiveType.tarBzip2 => name.toLowerCase().endsWith('.tbz2')
          ? '.tbz2'
          : name.toLowerCase().endsWith('.tbz')
              ? '.tbz'
              : '.tar.bz2',
      _ArchiveType.tarXz =>
        name.toLowerCase().endsWith('.txz') ? '.txz' : '.tar.xz',
    };
    final baseName = name.substring(0, name.length - suffix.length);
    return baseName.isEmpty ? 'archive' : baseName;
  }

  Future<String> _availableExtractionPath(
    String parentPath,
    String archiveName,
  ) async {
    var candidate = p.join(parentPath, archiveName);
    var suffix = 1;
    while (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      candidate = p.join(parentPath, '$archiveName ($suffix)');
      suffix++;
    }
    return candidate;
  }

  Future<void> copyEntity(String src, String destDir) async {
    final dest = p.join(destDir, p.basename(src));
    if (FileSystemEntity.isDirectorySync(src)) {
      await _copyDir(Directory(src), Directory(dest));
    } else {
      await File(src).copy(dest);
    }
  }

  Future<String> copyEntityUnique(String src, String destDir) async {
    final sourceType = await FileSystemEntity.type(src, followLinks: false);
    final destination = await _uniqueEntityPath(
      destDir,
      p.basename(src),
      isDirectory: sourceType == FileSystemEntityType.directory,
    );
    if (sourceType == FileSystemEntityType.directory) {
      await _copyDir(Directory(src), Directory(destination));
    } else if (sourceType == FileSystemEntityType.file) {
      await File(src).copy(destination);
    } else {
      throw FileSystemException('Unsupported file system entry.', src);
    }
    return destination;
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

  Future<String> moveEntityUnique(String src, String destDir) async {
    final isDirectory =
        await FileSystemEntity.type(src, followLinks: false) ==
            FileSystemEntityType.directory;
    final destination = await _uniqueEntityPath(
      destDir,
      p.basename(src),
      isDirectory: isDirectory,
    );
    try {
      if (isDirectory) {
        await Directory(src).rename(destination);
      } else {
        await File(src).rename(destination);
      }
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 18 &&
          error.osError?.errorCode != 17) {
        rethrow;
      }
      final copiedPath = await copyEntityUnique(src, destDir);
      await deleteEntity(src);
      return copiedPath;
    }
    return destination;
  }

  Future<String> _uniqueEntityPath(
    String directory,
    String name, {
    required bool isDirectory,
  }) async {
    var candidate = p.join(directory, name);
    var suffix = 1;
    while (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final base = isDirectory ? name : p.basenameWithoutExtension(name);
      final extension = isDirectory ? '' : p.extension(name);
      candidate = p.join(directory, '$base ($suffix)$extension');
      suffix++;
    }
    return candidate;
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

class _DesktopEntry {
  const _DesktopEntry({
    required this.name,
    required this.mimeTypes,
    required this.hidden,
    required this.noDisplay,
  });

  final String name;
  final List<String> mimeTypes;
  final bool hidden;
  final bool noDisplay;
}
