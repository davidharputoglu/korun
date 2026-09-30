import 'dart:io';
import 'package:path/path.dart' as p;

class FileEntry {
  FileEntry({required this.path, required this.stat, required this.isDir});
  final String path;
  final FileStat stat;
  final bool isDir;

  String get name => p.basename(path);
  bool get isHidden => name.startsWith('.');
  int get size => stat.size;
  DateTime get modified => stat.modified;
  DateTime get accessed => stat.accessed;
  String get extension => p.extension(name).toLowerCase();
}
