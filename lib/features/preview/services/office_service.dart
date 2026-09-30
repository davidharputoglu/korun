import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Aperçu RÉEL des documents Office : conversion LibreOffice headless -> PDF.
class OfficeService {
  static const List<String> exts = [
    '.doc', '.docx', '.odt', '.rtf',
    '.xls', '.xlsx', '.ods',
    '.ppt', '.pptx', '.odp',
  ];

  static final Map<String, String?> _cache = {};

  static Future<bool> isAvailable() async {
    try {
      final r = await Process.run('which', ['soffice']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> toPdf(String path, DateTime mtime) async {
    final key = '$path|${mtime.millisecondsSinceEpoch}';
    if (_cache.containsKey(key)) return _cache[key];
    final hash = sha256.convert(key.codeUnits).toString().substring(0, 16);
    final out = '${Directory.systemTemp.path}/korun_office_$hash.pdf';
    if (File(out).existsSync()) {
      _cache[key] = out;
      return out;
    }
    try {
      final r = await Process.run('soffice', [
        '--headless', '--convert-to', 'pdf',
        '--outdir', Directory.systemTemp.path, path,
      ]);
      final produced = p.join(
          Directory.systemTemp.path, '${p.basenameWithoutExtension(path)}.pdf');
      if (r.exitCode == 0 && File(produced).existsSync()) {
        if (produced != out) File(produced).renameSync(out);
        _cache[key] = out;
        return out;
      }
    } catch (_) {}
    _cache[key] = null;
    return null;
  }
}
