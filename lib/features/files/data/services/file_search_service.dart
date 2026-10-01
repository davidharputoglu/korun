import 'dart:io';
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/platform/platform_service.dart';

class SearchResult {
  const SearchResult({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
}

class SearchProgress {
  const SearchProgress({
    required this.scanning,
    required this.indexedEntries,
    required this.scannedRoots,
    required this.totalRoots,
  });

  final bool scanning;
  final int indexedEntries;
  final int scannedRoots;
  final int totalRoots;
}

class FileSearchService {
  FileSearchService({
    required PlatformService platform,
    String? databasePath,
  })  : _platform = platform,
        _databasePath = databasePath;

  final PlatformService _platform;
  final String? _databasePath;
  Database? _database;
  Future<void>? _indexTask;
  DateTime? _lastIndexCompletedAt;
  SearchProgress _progress = const SearchProgress(
    scanning: false,
    indexedEntries: 0,
    scannedRoots: 0,
    totalRoots: 0,
  );

  SearchProgress get progress => _progress;

  Future<List<String>> _allRoots() async {
    final platformRoots = await _platform.searchRoots();
    final preferences = await SharedPreferences.getInstance();
    final configuredRoots = preferences.getStringList('search.roots') ?? [];
    return {...platformRoots, ...configuredRoots}.toList();
  }

  Future<void> addSearchRoot(String path) async {
    final normalizedPath = p.normalize(path);
    if (await FileSystemEntity.type(normalizedPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException('Search location is not a directory.', path);
    }
    final preferences = await SharedPreferences.getInstance();
    final roots = preferences.getStringList('search.roots') ?? [];
    if (roots.contains(normalizedPath)) return;
    roots.add(normalizedPath);
    await preferences.setStringList('search.roots', roots);
  }

  Future<Database> _openDatabase() async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    final path = _databasePath ?? await _defaultDatabasePath();
    await Directory(p.dirname(path)).create(recursive: true);
    _database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE entries (
              path TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              name_lower TEXT NOT NULL,
              path_lower TEXT NOT NULL,
              extension TEXT NOT NULL,
              is_directory INTEGER NOT NULL,
              size INTEGER NOT NULL,
              modified_ms INTEGER NOT NULL,
              root TEXT NOT NULL,
              generation INTEGER NOT NULL
            )
          ''');
          await database.execute(
            'CREATE INDEX entries_extension ON entries(extension)',
          );
          await database.execute(
            'CREATE INDEX entries_modified ON entries(modified_ms)',
          );
          await database.execute('CREATE INDEX entries_root ON entries(root)');
        },
      ),
    );
    return _database!;
  }

  Future<String> _defaultDatabasePath() async {
    final base = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA'] ??
            p.join(_platform.homePath, 'AppData', 'Local')
        : Platform.environment['XDG_CACHE_HOME'] ??
            p.join(_platform.homePath, '.cache');
    return p.join(base, 'korun', 'search-index.db');
  }

  Future<void> indexAll({
    required void Function(SearchProgress progress) onProgress,
    bool force = false,
  }) async {
    if (_indexTask != null) return _indexTask!;
    if (!force &&
        _lastIndexCompletedAt != null &&
        DateTime.now().difference(_lastIndexCompletedAt!) <
            const Duration(minutes: 15)) {
      return;
    }
    _indexTask = _indexAll(onProgress);
    try {
      await _indexTask;
      _lastIndexCompletedAt = DateTime.now();
    } catch (_) {
      _progress = SearchProgress(
        scanning: false,
        indexedEntries: _progress.indexedEntries,
        scannedRoots: _progress.scannedRoots,
        totalRoots: _progress.totalRoots,
      );
      onProgress(_progress);
      rethrow;
    } finally {
      _indexTask = null;
    }
  }

  Future<void> _indexAll(
    void Function(SearchProgress progress) onProgress,
  ) async {
    final database = await _openDatabase();
    final roots = await _allRoots();
    var totalIndexed = 0;
    var scannedRoots = 0;
    _progress = SearchProgress(
      scanning: true,
      indexedEntries: totalIndexed,
      scannedRoots: scannedRoots,
      totalRoots: roots.length,
    );
    onProgress(_progress);

    for (final root in roots) {
      final generation = DateTime.now().microsecondsSinceEpoch;
      var batch = <Map<String, Object?>>[];
      var rootScanComplete = true;
      try {
        final pendingDirectories = <String>[root];
        while (pendingDirectories.isNotEmpty) {
          final directoryPath = pendingDirectories.removeLast();
          if (_skipDirectory(directoryPath, root)) continue;
          try {
            await for (final entity in Directory(directoryPath)
                .list(followLinks: false)
                .timeout(const Duration(seconds: 15))) {
              if (entity is Link) continue;
              final isDirectory = entity is Directory;
              if (isDirectory) {
                pendingDirectories.add(entity.path);
              } else if (entity is! File) {
                continue;
              }

              try {
                final stat = await entity
                    .stat()
                    .timeout(const Duration(seconds: 5));
                final name = p.basename(entity.path);
                batch.add({
                  'path': entity.path,
                  'name': name,
                  'name_lower': name.toLowerCase(),
                  'path_lower': entity.path.toLowerCase(),
                  'extension': isDirectory ? '' : p.extension(name).toLowerCase(),
                  'is_directory': isDirectory ? 1 : 0,
                  'size': isDirectory ? 0 : stat.size,
                  'modified_ms': stat.modified.millisecondsSinceEpoch,
                  'root': root,
                  'generation': generation,
                });
                totalIndexed++;
              } on FileSystemException {
                rootScanComplete = false;
                continue;
              } on TimeoutException {
                rootScanComplete = false;
                continue;
              }

              if (batch.length >= 400) {
                await _storeBatch(database, batch);
                batch = <Map<String, Object?>>[];
                _progress = SearchProgress(
                  scanning: true,
                  indexedEntries: totalIndexed,
                  scannedRoots: scannedRoots,
                  totalRoots: roots.length,
                );
                onProgress(_progress);
              }
            }
          } on FileSystemException {
            rootScanComplete = false;
            continue;
          } on TimeoutException {
            rootScanComplete = false;
            continue;
          }
        }
        if (batch.isNotEmpty) await _storeBatch(database, batch);
      } on FileSystemException {
        rootScanComplete = false;
        // A root can disappear while a removable or network volume is scanned.
      }
      if (rootScanComplete) {
        await database.delete(
          'entries',
          where: 'root = ? AND generation != ?',
          whereArgs: [root, generation],
        );
      }
      scannedRoots++;
      _progress = SearchProgress(
        scanning: true,
        indexedEntries: totalIndexed,
        scannedRoots: scannedRoots,
        totalRoots: roots.length,
      );
      onProgress(_progress);
    }
    _progress = SearchProgress(
      scanning: false,
      indexedEntries: totalIndexed,
      scannedRoots: scannedRoots,
      totalRoots: roots.length,
    );
    onProgress(_progress);
  }

  bool _skipDirectory(String path, String root) {
    final name = p.basename(path).toLowerCase();
    if (Platform.isLinux && path == root && root == '/') return false;
    if (Platform.isLinux &&
        const {'proc', 'sys', 'dev', 'run'}.contains(name)) {
      return true;
    }
    if (Platform.isWindows &&
        const {'system volume information', r'$recycle.bin'}.contains(name)) {
      return true;
    }
    return false;
  }

  Future<void> _storeBatch(
    Database database,
    List<Map<String, Object?>> rows,
  ) async {
    final batch = database.batch();
    for (final row in rows) {
      batch.insert(
        'entries',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<SearchResult>> search(
    String query, {
    int limit = 500,
  }) async {
    final database = await _openDatabase();
    final clauses = <String>[];
    final arguments = <Object>[];
    for (final term in _tokenize(query)) {
      final separator = term.indexOf(':');
      if (separator < 0) {
        clauses.add('instr(name_lower, ?) > 0');
        arguments.add(term.toLowerCase());
        continue;
      }
      final key = term.substring(0, separator).toLowerCase();
      final value = term.substring(separator + 1);
      if (value.isEmpty) throw FormatException('Missing value for $key:');
      switch (key) {
        case 'name':
          clauses.add('instr(name_lower, ?) > 0');
          arguments.add(value.toLowerCase());
        case 'path':
        case 'in':
          clauses.add('instr(path_lower, ?) > 0');
          arguments.add(value.toLowerCase());
        case 'ext':
          clauses.add('extension = ?');
          arguments.add(value.startsWith('.') ? value.toLowerCase() : '.${value.toLowerCase()}');
        case 'type':
          final extensions = _typeExtensions(value.toLowerCase());
          if (extensions == null) {
            throw FormatException('Unknown type "$value". Use image, video, audio, document, archive, folder, or file.');
          }
          if (value.toLowerCase() == 'folder') {
            clauses.add('is_directory = 1');
          } else if (value.toLowerCase() == 'file') {
            clauses.add('is_directory = 0');
          } else {
            clauses.add('is_directory = 0 AND extension IN (${List.filled(extensions.length, '?').join(',')})');
            arguments.addAll(extensions);
          }
        case 'size':
          final size = _parseSize(value);
          clauses.add('is_directory = 0 AND size ${size.operator} ?');
          arguments.add(size.bytes);
        case 'date':
        case 'modified':
          final dateFilter =
              RegExp(r'^(>=|<=|>|<|=)?(.+)$').firstMatch(value);
          if (dateFilter == null) {
            throw FormatException('Invalid date filter "$value".');
          }
          final date = _parseDate(dateFilter.group(2)!);
          clauses.add('modified_ms ${dateFilter.group(1) ?? '>='} ?');
          arguments.add(date.millisecondsSinceEpoch);
        default:
          throw FormatException('Unknown search filter "$key".');
      }
    }

    final rows = await database.query(
      'entries',
      columns: ['path', 'name', 'is_directory', 'size', 'modified_ms'],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'name_lower',
      limit: limit,
    );
    return rows
        .map(
          (row) => SearchResult(
            path: row['path']! as String,
            name: row['name']! as String,
            isDirectory: row['is_directory']! == 1,
            size: row['size']! as int,
            modified: DateTime.fromMillisecondsSinceEpoch(
              row['modified_ms']! as int,
            ),
          ),
        )
        .toList();
  }

  List<String> _tokenize(String query) {
    final terms = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (final rune in query.trim().runes) {
      final character = String.fromCharCode(rune);
      if (character == '"') {
        quoted = !quoted;
      } else if (character.trim().isEmpty && !quoted) {
        if (current.isNotEmpty) {
          terms.add(current.toString());
          current.clear();
        }
      } else {
        current.write(character);
      }
    }
    if (quoted) throw const FormatException('Unclosed quote.');
    if (current.isNotEmpty) terms.add(current.toString());
    return terms;
  }

  List<String>? _typeExtensions(String type) => switch (type) {
        'image' => const [
            '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg', '.tif',
            '.tiff', '.ico', '.heic', '.avif',
          ],
        'video' => const [
            '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.mpeg',
            '.mpg', '.m4v', '.3gp', '.mts', '.m2ts',
          ],
        'audio' => const [
            '.mp3', '.wav', '.ogg', '.opus', '.flac', '.m4a', '.aac', '.wma',
            '.aiff',
          ],
        'document' => const [
            '.pdf', '.doc', '.docx', '.odt', '.rtf', '.txt', '.md', '.xls',
            '.xlsx', '.ods', '.ppt', '.pptx', '.csv', '.epub', '.mobi',
          ],
        'spreadsheet' => const [
            '.xls', '.xlsx', '.xlsm', '.ods', '.csv', '.tsv',
          ],
        'presentation' => const [
            '.ppt', '.pptx', '.pptm', '.odp', '.key',
          ],
        'code' => const [
            '.c', '.h', '.cpp', '.hpp', '.dart', '.py', '.js', '.ts', '.tsx',
            '.jsx', '.html', '.css', '.json', '.yaml', '.yml', '.xml', '.rs',
            '.go', '.java', '.kt', '.sh', '.bat', '.ps1', '.sql',
          ],
        'archive' => const [
            '.zip', '.rar', '.7z', '.cbz', '.cbr', '.tar', '.gz', '.bz2',
            '.xz', '.z', '.lzma', '.lz', '.lzo', '.zst', '.br', '.lz4',
            '.lrz', '.sz', '.tgz', '.tbz', '.tbz2', '.txz', '.taz', '.tz',
            '.tlz', '.tzo', '.tzst', '.t7z', '.tlrz', '.tsz',
          ],
        'folder' || 'file' => const [],
        _ => null,
      };

  ({String operator, int bytes}) _parseSize(String value) {
    final match = RegExp(r'^(>=|<=|>|<|=)?(\d+(?:\.\d+)?)(B|KB|MB|GB|TB)?$',
            caseSensitive: false)
        .firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid size "$value". Example: size:>10MB.');
    }
    final multiplier = switch ((match.group(3) ?? 'B').toUpperCase()) {
      'KB' => 1024,
      'MB' => 1024 * 1024,
      'GB' => 1024 * 1024 * 1024,
      'TB' => 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    final operator = match.group(1) ?? '=';
    final bytes = (double.parse(match.group(2)!) * multiplier).round();
    return (operator: operator, bytes: bytes);
  }

  DateTime _parseDate(String value) {
    final now = DateTime.now();
    if (value.toLowerCase() == 'today') {
      return DateTime(now.year, now.month, now.day);
    }
    final days = RegExp(r'^(\d+)d$', caseSensitive: false).firstMatch(value);
    if (days != null) {
      return now.subtract(Duration(days: int.parse(days.group(1)!)));
    }
    final date = DateTime.tryParse(value);
    if (date != null) return date;
    throw FormatException('Invalid date "$value". Use today, 7d, or YYYY-MM-DD.');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
