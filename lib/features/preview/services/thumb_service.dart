import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ArchiveImagePreview {
  const ArchiveImagePreview({required this.name, required this.path});

  final String name;
  final String path;
}

class ArchivePreviewData {
  const ArchivePreviewData({required this.entries, required this.images});

  final List<String> entries;
  final List<ArchiveImagePreview> images;
}

/// Vraies miniatures : ffmpeg système (vidéo/audio) + lecture d'archives.
class ThumbService {
  static final Map<String, Future<String?>> _videoCache =
      <String, Future<String?>>{};
  static final Map<String, Future<String?>> _audioCache =
      <String, Future<String?>>{};
  static final Map<String, Future<ArchivePreviewData>> _archiveCache =
      <String, Future<ArchivePreviewData>>{};

  static String _tmpFor(String path, String kind) =>
      '${Directory.systemTemp.path}/korun_${kind}_${path.hashCode.toUnsigned(31)}.png';

  /// Vidéo : vraie miniature = frame extraite à 1 s.
  static Future<String?> videoThumb(String path) =>
      _videoCache.putIfAbsent(path, () => _createVideoThumb(path));

  static Future<String?> _createVideoThumb(String path) async {
    final out = _tmpFor(path, 'vid');
    String? result;
    if (File(out).existsSync()) {
      result = out;
    } else {
      try {
        final exitCode = await _runFfmpeg([
          '-y',
          '-nostdin',
          '-v',
          'error',
          '-ss',
          '1',
          '-i',
          path,
          '-frames:v',
          '1',
          '-vf',
          'scale=480:-1',
          out,
        ]);
        if (exitCode == 0 && File(out).existsSync()) result = out;
      } catch (_) {
        result = null; // ffmpeg absent -> le panneau affiche l'icône typée
      }
    }
    return result;
  }

  /// Audio : pochette intégrée extraite si elle existe.
  static Future<String?> audioCover(String path) =>
      _audioCache.putIfAbsent(path, () => _createAudioCover(path));

  static Future<String?> _createAudioCover(String path) async {
    final out = _tmpFor(path, 'aud');
    String? result;
    if (File(out).existsSync()) {
      result = out;
    } else {
      try {
        final exitCode = await _runFfmpeg([
          '-y',
          '-nostdin',
          '-v',
          'error',
          '-i',
          path,
          '-an',
          '-vframes',
          '1',
          out,
        ]);
        if (exitCode == 0 && File(out).existsSync()) result = out;
      } catch (_) {
        result = null;
      }
    }
    return result;
  }

  /// Liste une archive sans bloquer l'interface et extrait un nombre limité
  /// de petites images pour les aperçus ZIP/CBZ et TAR compressés.
  static Future<ArchivePreviewData> archivePreview(String path) async {
    final stat = await File(path).stat();
    final key = '$path:${stat.modified.millisecondsSinceEpoch}:${stat.size}';
    return _archiveCache.putIfAbsent(
      key,
      () async {
        if (_archiveCache.length >= 32) {
          _archiveCache.remove(_archiveCache.keys.first);
        }
        final result = await Isolate.run(() => _archivePreviewInBackground(path));
        return _archivePreviewFromMap(result);
      },
    );
  }

  static Future<int> _runFfmpeg(List<String> arguments) async {
    final process = await Process.start('ffmpeg', arguments);
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr.drain<void>();
    var timedOut = false;
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        timedOut = true;
        process.kill();
        return -1;
      },
    );
    await Future.wait([stdoutDone, stderrDone]);
    if (timedOut) return -1;
    return exitCode;
  }
}

Map<String, Object> _archivePreviewInBackground(String path) {
  InputFileStream? input;
  try {
    if (File(path).lengthSync() > 64 * 1024 * 1024) {
      return {'entries': const <String>[], 'images': const <List<String>>[]};
    }
    final lower = path.toLowerCase();
    Archive? archive;
    if (lower.endsWith('.zip')) {
      input = InputFileStream(path);
      archive = ZipDecoder().decodeStream(input);
    } else if (lower.endsWith('.tar')) {
      input = InputFileStream(path);
      archive = TarDecoder().decodeStream(input);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(File(path).readAsBytesSync()),
      );
    } else if (lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz') ||
        lower.endsWith('.tbz2')) {
      archive = TarDecoder().decodeBytes(
        BZip2Decoder().decodeBytes(File(path).readAsBytesSync()),
      );
    } else if (lower.endsWith('.tar.xz') || lower.endsWith('.txz')) {
      archive = TarDecoder().decodeBytes(
        XZDecoder().decodeBytes(File(path).readAsBytesSync()),
      );
    }
    if (archive == null) {
      return {'entries': const <String>[], 'images': const <List<String>>[]};
    }
    final entries = <String>[];
    final images = <List<String>>[];
    final previewDirectory = Directory(
      '${Directory.systemTemp.path}/korun_archive_${path.hashCode.toUnsigned(31)}',
    )..createSync(recursive: true);
    for (final entry in archive.files) {
      if (entry.isDirectory) continue;
      if (entries.length < 300) entries.add(entry.name);
      final ext = p.extension(entry.name).toLowerCase();
      if (images.length >= 12 ||
          entry.size <= 0 ||
          entry.size > 5 * 1024 * 1024 ||
          !const {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'}
              .contains(ext)) {
        continue;
      }
      final previewPath = p.join(previewDirectory.path, '${images.length}$ext');
      final output = OutputFileStream(previewPath);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      images.add([entry.name, previewPath]);
    }
    return {'entries': entries, 'images': images};
  } catch (_) {
    return {'entries': const <String>[], 'images': const <List<String>>[]};
  } finally {
    input?.closeSync();
  }
}

ArchivePreviewData _archivePreviewFromMap(Map<String, Object?> value) =>
    ArchivePreviewData(
      entries: (value['entries']! as List<Object?>).cast<String>(),
      images: (value['images']! as List<Object?>)
          .cast<List<Object?>>()
          .map(
            (image) => ArchiveImagePreview(
              name: image[0]! as String,
              path: image[1]! as String,
            ),
          )
          .toList(),
    );
