import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

/// Vraies miniatures : ffmpeg système (vidéo/audio) + lecture d'archives.
class ThumbService {
  static final Map<String, Future<String?>> _videoCache =
      <String, Future<String?>>{};
  static final Map<String, Future<String?>> _audioCache =
      <String, Future<String?>>{};
  static final Map<String, Future<List<String>>> _archiveCache =
      <String, Future<List<String>>>{};

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

  /// Archives : liste RÉELLE du contenu (zip/tar/gz/bz2/xz).
  static Future<List<String>> archiveEntries(String path) async {
    final stat = await File(path).stat();
    final key = '$path:${stat.modified.millisecondsSinceEpoch}:${stat.size}';
    return _archiveCache.putIfAbsent(
      key,
      () {
        if (_archiveCache.length >= 32) {
          _archiveCache.remove(_archiveCache.keys.first);
        }
        return Isolate.run(() => _archiveEntriesInBackground(path));
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

List<String> _archiveEntriesInBackground(String path) {
  InputFileStream? input;
  try {
    if (File(path).lengthSync() > 64 * 1024 * 1024) return const [];
    final lower = path.toLowerCase();
    Archive? archive;
    if (lower.endsWith('.zip')) {
      input = InputFileStream(path);
      archive = ZipDecoder().decodeStream(input);
    } else if (lower.endsWith('.tar')) {
      input = InputFileStream(path);
      archive = TarDecoder().decodeStream(input);
    } else if (lower.endsWith('.gz')) {
      archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(File(path).readAsBytesSync()),
      );
    } else if (lower.endsWith('.bz2')) {
      archive = TarDecoder().decodeBytes(
        BZip2Decoder().decodeBytes(File(path).readAsBytesSync()),
      );
    } else if (lower.endsWith('.xz')) {
      archive = TarDecoder().decodeBytes(
        XZDecoder().decodeBytes(File(path).readAsBytesSync()),
      );
    }
    return archive?.files.take(300).map((file) => file.name).toList() ??
        const [];
  } catch (_) {
    return const [];
  } finally {
    input?.closeSync();
  }
}
