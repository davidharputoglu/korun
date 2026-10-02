import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';

enum SortBy { name, size, date }
enum ViewMode { list, grid }
enum ArchiveFormat {
  zip('.zip'),
  tar('.tar'),
  tarGzip('.tar.gz'),
  tarBzip2('.tar.bz2'),
  tarXz('.tar.xz'),
  sevenZip('.7z'),
  rar('.rar'),
  gzip('.gz'),
  bzip2('.bz2'),
  xz('.xz');

  const ArchiveFormat(this.extension);

  final String extension;

  String get localizationKey => switch (this) {
        ArchiveFormat.zip => 'archive_format_zip',
        ArchiveFormat.tar => 'archive_format_tar',
        ArchiveFormat.tarGzip => 'archive_format_tar_gzip',
        ArchiveFormat.tarBzip2 => 'archive_format_tar_bzip2',
        ArchiveFormat.tarXz => 'archive_format_tar_xz',
        ArchiveFormat.sevenZip => 'archive_format_7z',
        ArchiveFormat.rar => 'archive_format_rar',
        ArchiveFormat.gzip => 'archive_format_gzip',
        ArchiveFormat.bzip2 => 'archive_format_bzip2',
        ArchiveFormat.xz => 'archive_format_xz',
      };

  String get sevenZipType => switch (this) {
        ArchiveFormat.zip => 'zip',
        ArchiveFormat.tar => 'tar',
        ArchiveFormat.sevenZip => '7z',
        ArchiveFormat.rar => throw UnsupportedError(
            'RAR creation requires WinRAR or the RAR command-line tool.',
          ),
        ArchiveFormat.gzip => 'gzip',
        ArchiveFormat.bzip2 => 'bzip2',
        ArchiveFormat.xz => 'xz',
        _ => throw UnsupportedError(
            '7-Zip does not create ${extension} archives via a single pass.',
          ),
      };
}

enum CompressionEngine { korun, sevenZip, winRar }

enum _ArchiveType {
  zip,
  tar,
  tarGzip,
  tarBzip2,
  tarXz,
  sevenZip,
  rar,
  gzipFile,
  bzip2File,
  xzFile,
}

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
  ) =>
      compressToArchive(paths, archivePath, format: ArchiveFormat.zip);

  Future<String> compressToArchive(
    List<String> paths,
    String archivePath, {
    required ArchiveFormat format,
    CompressionEngine engine = CompressionEngine.korun,
  }) async {
    if (paths.isEmpty) {
      throw ArgumentError('Select at least one file or folder.');
    }
    if (!archivePath.toLowerCase().endsWith(format.extension)) {
      throw ArgumentError.value(
        archivePath,
        'archivePath',
        'Archive path must end with ${format.extension}.',
      );
    }
    if (await FileSystemEntity.type(
          archivePath,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('The archive already exists.', archivePath);
    }

    if (engine == CompressionEngine.sevenZip) {
      return _compressWithSevenZip(paths, archivePath, format);
    }
    if (engine == CompressionEngine.winRar) {
      if (format != ArchiveFormat.rar) {
        throw UnsupportedError('WinRAR is used for RAR archive creation.');
      }
      return _compressWithWinRar(paths, archivePath);
    }
    if (format == ArchiveFormat.sevenZip) {
      throw UnsupportedError('7z archive creation requires 7-Zip.');
    }
    if (format == ArchiveFormat.rar) {
      throw UnsupportedError('RAR archive creation requires WinRAR.');
    }
    if (format == ArchiveFormat.gzip ||
        format == ArchiveFormat.bzip2 ||
        format == ArchiveFormat.xz) {
      return _compressStandalone(paths, archivePath, format);
    }
    if (format != ArchiveFormat.zip) {
      return _compressTarArchive(paths, archivePath, format);
    }
    return _compressZipArchive(paths, archivePath);
  }

  static Future<String?> findSevenZipExecutable() async {
    final executableNames = Platform.isWindows
        ? const ['7z.exe', '7zz.exe', '7za.exe']
        : const ['7zz', '7z', '7za'];
    final candidates = <String>[];
    if (Platform.isWindows) {
      final programFiles = [
        Platform.environment['ProgramFiles'],
        Platform.environment['ProgramFiles(x86)'],
      ].whereType<String>();
      for (final directory in programFiles) {
        candidates.add(p.join(directory, '7-Zip', '7z.exe'));
      }
    }
    for (final directory in (Platform.environment['PATH'] ?? '')
        .split(Platform.isWindows ? ';' : ':')) {
      if (directory.isEmpty) continue;
      for (final name in executableNames) {
        candidates.add(p.join(directory, name));
      }
    }
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  static Future<String?> findWinRarExecutable() async {
    final candidates = <String>[];
    if (Platform.isWindows) {
      for (final directory in [
        Platform.environment['ProgramFiles'],
        Platform.environment['ProgramFiles(x86)'],
      ].whereType<String>()) {
        candidates.add(p.join(directory, 'WinRAR', 'Rar.exe'));
      }
      for (final directory in (Platform.environment['PATH'] ?? '').split(';')) {
        if (directory.isNotEmpty) candidates.add(p.join(directory, 'Rar.exe'));
      }
    } else {
      for (final directory in (Platform.environment['PATH'] ?? '').split(':')) {
        if (directory.isNotEmpty) candidates.add(p.join(directory, 'rar'));
      }
    }
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  Future<String> _compressWithSevenZip(
    List<String> paths,
    String archivePath,
    ArchiveFormat format,
  ) async {
    final executable = await findSevenZipExecutable();
    if (executable == null) {
      throw UnsupportedError('7-Zip is not installed or was not found.');
    }
    final type = format.sevenZipType;
    final parent = Directory(p.dirname(archivePath));
    final staging = await parent.createTemp('.korun-compress-');
    final stagedArchive = p.join(staging.path, 'archive${format.extension}');
    final inputs = _externalArchiveInputs(paths);
    try {
      final result = await Process.run(
        executable,
        ['a', '-t$type', stagedArchive, ...inputs.paths],
        workingDirectory: inputs.workingDirectory,
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          '7-Zip failed: ${result.stderr}',
          archivePath,
        );
      }
      if (await FileSystemEntity.type(archivePath, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FileSystemException('The archive already exists.', archivePath);
      }
      await File(stagedArchive).rename(archivePath);
      return archivePath;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<String> _compressWithWinRar(
    List<String> paths,
    String archivePath,
  ) async {
    final executable = await findWinRarExecutable();
    if (executable == null) {
      throw UnsupportedError('WinRAR/RAR was not found.');
    }
    final parent = Directory(p.dirname(archivePath));
    final staging = await parent.createTemp('.korun-compress-');
    final stagedArchive =
        p.join(staging.path, 'archive${p.extension(archivePath)}');
    final inputs = _externalArchiveInputs(paths);
    try {
      final result = await Process.run(
        executable,
        ['a', '-r', stagedArchive, ...inputs.paths],
        workingDirectory: inputs.workingDirectory,
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          'WinRAR/RAR failed: ${result.stderr}',
          archivePath,
        );
      }
      if (await FileSystemEntity.type(archivePath, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FileSystemException('The archive already exists.', archivePath);
      }
      await File(stagedArchive).rename(archivePath);
      return archivePath;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  ({String workingDirectory, List<String> paths}) _externalArchiveInputs(
    List<String> paths,
  ) {
    final workingDirectory = p.dirname(paths.first);
    if (paths.every(
      (path) => p.equals(p.dirname(path), workingDirectory),
    )) {
      return (
        workingDirectory: workingDirectory,
        paths: paths.map(p.basename).toList(),
      );
    }
    return (
      workingDirectory: Directory.current.path,
      paths: paths,
    );
  }

  Future<String> _compressStandalone(
    List<String> paths,
    String archivePath,
    ArchiveFormat format,
  ) async {
    if (paths.length != 1 ||
        await FileSystemEntity.type(paths.single, followLinks: false) !=
            FileSystemEntityType.file) {
      throw ArgumentError(
        'GZIP, BZIP2, and XZ standalone formats require exactly one file.',
      );
    }
    final contents = await File(paths.single).readAsBytes();
    final compressed = switch (format) {
      ArchiveFormat.gzip => GZipEncoder().encode(contents),
      ArchiveFormat.bzip2 => BZip2Encoder().encode(contents),
      ArchiveFormat.xz => XZEncoder().encode(contents),
      _ => throw ArgumentError.value(format, 'format'),
    };
    final output = File(archivePath);
    await output.create(exclusive: true);
    try {
      await output.writeAsBytes(compressed, flush: true);
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
    return archivePath;
  }

  Future<String> _compressZipArchive(
    List<String> paths,
    String archivePath,
  ) async {
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

  Future<String> _compressTarArchive(
    List<String> paths,
    String archivePath,
    ArchiveFormat format,
  ) async {
    final archive = Archive();
    final inputStreams = <InputFileStream>[];
    try {
      for (final sourcePath in paths) {
        final sourceName = p.basename(sourcePath);
        final type =
            await FileSystemEntity.type(sourcePath, followLinks: false);
        if (type == FileSystemEntityType.file) {
          await _addFileToTar(
            archive,
            File(sourcePath),
            sourceName,
            inputStreams,
          );
        } else if (type == FileSystemEntityType.directory) {
          await _addDirectoryToTar(
            archive,
            Directory(sourcePath),
            sourceName,
            inputStreams,
          );
        } else {
          throw FileSystemException(
            'Unsupported file system entry.',
            sourcePath,
          );
        }
      }

      if (format == ArchiveFormat.tar) {
        final output = File(archivePath);
        await output.create(exclusive: true);
        OutputFileStream? outputStream;
        try {
          outputStream = OutputFileStream(archivePath);
          TarEncoder().encode(archive, output: outputStream);
          await outputStream.close();
        } catch (_) {
          if (outputStream != null) await outputStream.close();
          if (await output.exists()) await output.delete();
          rethrow;
        }
        return archivePath;
      }

      final tarBytes = TarEncoder().encode(archive);
      final bytes = switch (format) {
        ArchiveFormat.tarGzip => GZipEncoder().encode(tarBytes),
        ArchiveFormat.tarBzip2 => BZip2Encoder().encode(tarBytes),
        ArchiveFormat.tarXz => XZEncoder().encode(tarBytes),
        ArchiveFormat.zip ||
        ArchiveFormat.tar ||
        ArchiveFormat.sevenZip ||
        ArchiveFormat.rar ||
        ArchiveFormat.gzip ||
        ArchiveFormat.bzip2 ||
        ArchiveFormat.xz =>
          throw ArgumentError.value(format, 'format'),
      };
      final output = File(archivePath);
      await output.create(exclusive: true);
      try {
        await output.writeAsBytes(bytes, flush: true);
      } catch (_) {
        if (await output.exists()) await output.delete();
        rethrow;
      }
      return archivePath;
    } finally {
      for (final inputStream in inputStreams) {
        await inputStream.close();
      }
    }
  }

  Future<void> _addDirectoryToTar(
    Archive archive,
    Directory directory,
    String archiveDirectory,
    List<InputFileStream> inputStreams,
  ) async {
    final children =
        await directory.list(followLinks: false, recursive: false).toList();
    if (children.isEmpty) {
      archive.addFile(ArchiveFile.directory('$archiveDirectory/'));
      return;
    }
    for (final child in children) {
      final name = p.posix.join(archiveDirectory, p.basename(child.path));
      if (child is Directory) {
        await _addDirectoryToTar(archive, child, name, inputStreams);
      } else if (child is File) {
        await _addFileToTar(archive, child, name, inputStreams);
      }
    }
  }

  Future<void> _addFileToTar(
    Archive archive,
    File file,
    String archivePath,
    List<InputFileStream> inputStreams,
  ) async {
    final input = InputFileStream(file.path);
    inputStreams.add(input);
    final entry = ArchiveFile.stream(archivePath, input)
      ..lastModTime =
          (await file.lastModified()).millisecondsSinceEpoch ~/ 1000;
    archive.addFile(entry);
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
        'TAR.BZ2, TAR.XZ, 7z, RAR, and standalone GZIP, BZIP2, and XZ files.',
        archivePath,
      );
    }
    if (const {
      _ArchiveType.gzipFile,
      _ArchiveType.bzip2File,
      _ArchiveType.xzFile,
    }.contains(archiveType)) {
      return _extractCompressedFile(archivePath, archiveType);
    }
    if (archiveType == _ArchiveType.sevenZip ||
        archiveType == _ArchiveType.rar) {
      return _extractWithArchiveTool(archivePath, archiveType);
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
        _ArchiveType.sevenZip ||
        _ArchiveType.rar =>
          throw StateError('External archive formats are extracted separately.'),
        _ArchiveType.gzipFile ||
        _ArchiveType.bzip2File ||
        _ArchiveType.xzFile =>
          throw StateError('Standalone codecs are extracted separately.'),
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
    if (lowerPath.endsWith('.7z')) return _ArchiveType.sevenZip;
    if (lowerPath.endsWith('.rar')) return _ArchiveType.rar;
    if (lowerPath.endsWith('.tar')) return _ArchiveType.tar;
    if (lowerPath.endsWith('.gz')) return _ArchiveType.gzipFile;
    if (lowerPath.endsWith('.bz2')) return _ArchiveType.bzip2File;
    if (lowerPath.endsWith('.xz')) return _ArchiveType.xzFile;
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
      _ArchiveType.sevenZip => '.7z',
      _ArchiveType.rar => '.rar',
      _ArchiveType.gzipFile => '.gz',
      _ArchiveType.bzip2File => '.bz2',
      _ArchiveType.xzFile => '.xz',
    };
    final baseName = name.substring(0, name.length - suffix.length);
    return baseName.isEmpty ? 'archive' : baseName;
  }

  Future<String> _extractWithArchiveTool(
    String archivePath,
    _ArchiveType type,
  ) async {
    final sevenZip = await findSevenZipExecutable();
    final winRar = type == _ArchiveType.rar
        ? await findWinRarExecutable()
        : null;
    final executable = winRar ?? sevenZip;
    if (executable == null) {
      throw UnsupportedError(
        '${type == _ArchiveType.rar ? 'WinRAR or 7-Zip' : '7-Zip'} is required '
        'to extract this format.',
      );
    }

    final parent = Directory(p.dirname(archivePath));
    final staging = await parent.createTemp('.korun-extract-');
    try {
      final arguments = executable == winRar
          ? ['x', '-y', archivePath, '${staging.path}${p.separator}']
          : ['x', archivePath, '-o${staging.path}', '-y', '-spf-'];
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: parent.path,
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          'Archive tool failed: ${result.stderr}',
          archivePath,
        );
      }
      var hasEntries = false;
      await for (final entry in staging.list(
        recursive: true,
        followLinks: false,
      )) {
        hasEntries = true;
        if (entry is Link) {
          throw FormatException(
            'Symbolic links are not allowed in extracted archives.',
          );
        }
      }
      if (!hasEntries) {
        throw FormatException('The archive contains no extractable files.');
      }
      final outputPath =
          await _availableExtractionPath(parent.path, _archiveBaseName(
        archivePath,
        type,
      ));
      await staging.rename(outputPath);
      return outputPath;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<String> _extractCompressedFile(
    String archivePath,
    _ArchiveType type,
  ) async {
    final compressed = await File(archivePath).readAsBytes();
    final contents = switch (type) {
      _ArchiveType.gzipFile => GZipDecoder().decodeBytes(compressed),
      _ArchiveType.bzip2File => BZip2Decoder().decodeBytes(compressed),
      _ArchiveType.xzFile => XZDecoder().decodeBytes(compressed),
      _ => throw ArgumentError.value(type, 'type', 'Not a standalone codec'),
    };
    final parentPath = p.dirname(archivePath);
    final baseName = _archiveBaseName(archivePath, type);
    var outputPath = p.join(parentPath, baseName);
    var suffix = 1;
    while (true) {
      final output = File(outputPath);
      try {
        await output.create(exclusive: true);
        try {
          await output.writeAsBytes(contents, flush: true);
          return outputPath;
        } catch (_) {
          if (await output.exists()) await output.delete();
          rethrow;
        }
      } on FileSystemException {
        if (await FileSystemEntity.type(outputPath, followLinks: false) ==
            FileSystemEntityType.notFound) {
          rethrow;
        }
        outputPath = p.join(parentPath, '$baseName ($suffix)');
        suffix++;
      }
    }
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
