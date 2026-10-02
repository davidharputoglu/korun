import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:korun/core/platform/platform_service.dart';
import 'package:korun/features/files/data/services/file_search_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _TestPlatform implements PlatformService {
  _TestPlatform(this.root);

  final String root;

  @override
  String get homePath => root;

  @override
  Future<String?> getQuickFolderPath(QuickFolder folder) async => null;

  @override
  Future<List<String>> searchRoots() async => [root];

  @override
  Future<String> createDesktopShortcut(String targetPath) async => targetPath;

  @override
  Future<void> composeEmail(List<String> attachments) async {}

  @override
  bool isHidden(String path) => false;

  @override
  Future<void> openExternal(String path) async {}

  @override
  List<String> get snapshotRoots => const [];
}

void main() {
  late Directory tempDirectory;
  late FileSearchService searchService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('korun_search_test_');
    await Directory(p.join(tempDirectory.path, 'Documents')).create();
    await File(p.join(tempDirectory.path, 'Documents', 'Annual Report.pdf'))
        .writeAsBytes(List<int>.filled(4096, 1));
    await File(p.join(tempDirectory.path, 'holiday.jpg')).writeAsBytes([1, 2]);
    await File(p.join(tempDirectory.path, 'notes.txt'))
        .writeAsString('A quick secret note.');
    searchService = FileSearchService(
      platform: _TestPlatform(tempDirectory.path),
      databasePath: p.join(tempDirectory.path, 'cache', 'search.db'),
    );
  });

  tearDown(() async {
    await searchService.close();
    await tempDirectory.delete(recursive: true);
  });

  test('indexes files and applies combined name, type, size, and path filters',
      () async {
    await searchService.indexAll(onProgress: (_) {});

    final results = await searchService.search(
      '"annual report" type:document size:>1KB in:Documents',
    );

    expect(results, hasLength(1));
    expect(results.single.name, 'Annual Report.pdf');
  });

  test('supports extension, date, and folder filters', () async {
    await searchService.indexAll(onProgress: (_) {});

    final images = await searchService.search('ext:jpg date:today');
    final folders = await searchService.search('type:folder name:Documents');

    expect(images.map((result) => result.name), ['holiday.jpg']);
    expect(folders.map((result) => result.name), ['Documents']);
    await expectLater(
      searchService.search('type:unknown'),
      throwsFormatException,
    );
  });

  test('searches text file contents only when requested', () async {
    await searchService.indexAll(onProgress: (_) {});

    final results = await searchService.search('content:"quick secret"');

    expect(results.map((result) => result.name), ['notes.txt']);
  });
}
