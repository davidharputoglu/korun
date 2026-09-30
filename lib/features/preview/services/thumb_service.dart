import 'dart:io';

import 'package:archive/archive.dart';

/// Vraies miniatures : ffmpeg système (vidéo/audio) + lecture d'archives.
class ThumbService {
  static final Map<String, String?> _videoCache = {};
  static final Map<String, String?> _audioCache = {};

  static String _tmpFor(String path, String kind) =>
      '${Directory.systemTemp.path}/korun_${kind}_${path.hashCode.toUnsigned(31)}.png';

  /// Vidéo : vraie miniature = frame extraite à 1 s.
  static Future<String?> videoThumb(String path) async {
    if (_videoCache.containsKey(path)) return _videoCache[path];
    final out = _tmpFor(path, 'vid');
    String? result;
    if (File(out).existsSync()) {
      result = out;
    } else {
      try {
        final r = await Process.run('ffmpeg',
            ['-y', '-ss', '1', '-i', path, '-frames:v', '1', '-vf', 'scale=480:-1', out]);
        if (r.exitCode == 0 && File(out).existsSync()) result = out;
      } catch (_) {
        result = null; // ffmpeg absent -> le panneau affiche l'icône typée
      }
    }
    _videoCache[path] = result;
    return result;
  }

  /// Audio : pochette intégrée extraite si elle existe.
  static Future<String?> audioCover(String path) async {
    if (_audioCache.containsKey(path)) return _audioCache[path];
    final out = _tmpFor(path, 'aud');
    String? result;
    if (File(out).existsSync()) {
      result = out;
    } else {
      try {
        final r = await Process.run('ffmpeg', ['-y', '-i', path, '-an', '-vframes', '1', out]);
        if (r.exitCode == 0 && File(out).existsSync()) result = out;
      } catch (_) {
        result = null;
      }
    }
    _audioCache[path] = result;
    return result;
  }

  /// Archives : liste RÉELLE du contenu (zip/tar/gz/bz2/xz).
  static Future<List<String>> archiveEntries(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final lower = path.toLowerCase();
      Archive? archive;
      if (lower.endsWith('.zip')) {
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (lower.endsWith('.tar')) {
        archive = TarDecoder().decodeBytes(bytes);
      } else if (lower.endsWith('.gz')) {
        archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      } else if (lower.endsWith('.bz2')) {
        archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
      } else if (lower.endsWith('.xz')) {
        archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
      }
      if (archive == null) return const [];
      return archive.files.take(300).map((f) => f.name).toList();
    } catch (_) {
      return const [];
    }
  }
}
