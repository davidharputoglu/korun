import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korun/features/files/data/services/file_system_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late FileSystemService fileSystem;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('korun_archive_test_');
    fileSystem = FileSystemService();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('compresses a folder and extracts its contents', () async {
    final source = Directory(p.join(tempDirectory.path, 'source'));
    await Directory(p.join(source.path, 'nested')).create(recursive: true);
    await File(p.join(source.path, 'nested', 'hello.txt'))
        .writeAsString('hello Körün');
    final archivePath = p.join(tempDirectory.path, 'source.zip');

    await fileSystem.compressToZip([source.path], archivePath);
    final extractedPath = await fileSystem.extractZip(archivePath);

    expect(
      await File(p.join(extractedPath, 'source', 'nested', 'hello.txt'))
          .readAsString(),
      'hello Körün',
    );
  });

  test('creates named TAR archive formats and extracts each one', () async {
    final source = Directory(p.join(tempDirectory.path, 'source'));
    await Directory(p.join(source.path, 'nested')).create(recursive: true);
    await File(p.join(source.path, 'nested', 'hello.txt'))
        .writeAsString('hello from TAR');

    final formats = {
      ArchiveFormat.tar: 'custom.tar',
      ArchiveFormat.tarGzip: 'custom.tar.gz',
      ArchiveFormat.tarBzip2: 'custom.tar.bz2',
      ArchiveFormat.tarXz: 'custom.tar.xz',
    };
    for (final format in formats.entries) {
      final archivePath = p.join(tempDirectory.path, format.value);
      await fileSystem.compressToArchive(
        [source.path],
        archivePath,
        format: format.key,
      );

      final extractedPath = await fileSystem.extractArchive(archivePath);
      expect(
        await File(p.join(extractedPath, 'source', 'nested', 'hello.txt'))
            .readAsString(),
        'hello from TAR',
        reason: 'Failed to create/extract ${format.value}',
      );
    }
  });

  test('applies selected compression levels to built-in ZIP and GZIP', () async {
    final source = File(p.join(tempDirectory.path, 'repeated.txt'));
    final contents = List.filled(1000, 'Körün compression test data. ').join();
    await source.writeAsString(contents);

    for (final level in [0, 1, 5, 9]) {
      final zipPath = p.join(tempDirectory.path, 'level-$level.zip');
      await fileSystem.compressToArchive(
        [source.path],
        zipPath,
        format: ArchiveFormat.zip,
        compressionLevel: level,
      );
      final extractedZip = await fileSystem.extractArchive(zipPath);
      expect(await File(p.join(extractedZip, 'repeated.txt')).readAsString(),
          contents);

      final gzipPath = p.join(tempDirectory.path, 'level-$level.txt.gz');
      await fileSystem.compressToArchive(
        [source.path],
        gzipPath,
        format: ArchiveFormat.gzip,
        compressionLevel: level,
      );
      final extractedGzip = await fileSystem.extractArchive(gzipPath);
      expect(await File(extractedGzip).readAsString(), contents);
    }
  });

  test('only reports levels for formats and engines that support them', () {
    expect(ArchiveFormat.tar.supportsCompressionLevel(CompressionEngine.korun),
        isFalse);
    expect(
      ArchiveFormat.bzip2.supportsCompressionLevel(CompressionEngine.korun),
      isFalse,
    );
    expect(ArchiveFormat.xz.supportsCompressionLevel(CompressionEngine.korun),
        isFalse);
    expect(
      ArchiveFormat.tarBzip2
          .supportsCompressionLevel(CompressionEngine.sevenZip),
      isTrue,
    );
    expect(ArchiveFormat.rar.supportsCompressionLevel(CompressionEngine.winRar),
        isTrue);
  });

  test('extracts TAR and supported compressed TAR variants', () async {
    final tar = Archive()
      ..addFile(ArchiveFile('folder/hello.txt', 5, 'hello'.codeUnits));
    final tarBytes = TarEncoder().encode(tar);
    final archives = <String, List<int>>{
      'plain.tar': tarBytes,
      'gzip.tar.gz': GZipEncoder().encode(tarBytes),
      'bzip.tar.bz2': BZip2Encoder().encode(tarBytes),
      'xz.tar.xz': XZEncoder().encode(tarBytes),
    };

    for (final archive in archives.entries) {
      final archivePath = p.join(tempDirectory.path, archive.key);
      await File(archivePath).writeAsBytes(archive.value);
      final extracted = await fileSystem.extractArchive(archivePath);
      expect(
        await File(p.join(extracted, 'folder', 'hello.txt')).readAsString(),
        'hello',
        reason: 'Failed to extract ${archive.key}',
      );
    }
  });

  test('extracts CBZ archives using ZIP extraction', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('page.txt', 4, 'page'.codeUnits));
    final archivePath = p.join(tempDirectory.path, 'comic.cbz');
    await File(archivePath).writeAsBytes(ZipEncoder().encode(archive));

    final extracted = await fileSystem.extractArchive(archivePath);

    expect(
      await File(p.join(extracted, 'page.txt')).readAsString(),
      'page',
    );
  });

  test('decompresses standalone GZIP, BZIP2, and XZ files', () async {
    const contents = 'compressed file content';
    final bytes = contents.codeUnits;
    final files = <String, List<int>>{
      'document.txt.gz': GZipEncoder().encode(bytes),
      'document.txt.bz2': BZip2Encoder().encode(bytes),
      'document.txt.xz': XZEncoder().encode(bytes),
    };

    for (final compressed in files.entries) {
      final formatDirectory = Directory(
        p.join(tempDirectory.path, p.extension(compressed.key).substring(1)),
      );
      await formatDirectory.create();
      final compressedPath = p.join(formatDirectory.path, compressed.key);
      await File(compressedPath).writeAsBytes(compressed.value);

      final extractedPath = await fileSystem.extractArchive(compressedPath);

      expect(p.basename(extractedPath), 'document.txt');
      expect(await File(extractedPath).readAsString(), contents);
      expect(await File(compressedPath).exists(), isTrue);
    }
  });

  test('creates and extracts standalone GZIP, BZIP2, and XZ files', () async {
    const contents = 'standalone compressed content';
    final source = File(p.join(tempDirectory.path, 'notes.txt'));
    await source.writeAsString(contents);
    final formats = {
      ArchiveFormat.gzip: 'notes.txt.gz',
      ArchiveFormat.bzip2: 'notes.txt.bz2',
      ArchiveFormat.xz: 'notes.txt.xz',
    };

    for (final format in formats.entries) {
      final archivePath = p.join(tempDirectory.path, format.value);
      await fileSystem.compressToArchive(
        [source.path],
        archivePath,
        format: format.key,
      );

      final extractedPath = await fileSystem.extractArchive(archivePath);
      expect(await File(extractedPath).readAsString(), contents);
    }
  });

  test('does not overwrite an existing standalone decompression output', () async {
    final compressedPath = p.join(tempDirectory.path, 'report.txt.gz');
    await File(compressedPath)
        .writeAsBytes(GZipEncoder().encode('new content'.codeUnits));
    final existing = File(p.join(tempDirectory.path, 'report.txt'));
    await existing.writeAsString('keep this file');

    final extractedPath = await fileSystem.extractArchive(compressedPath);

    expect(p.basename(extractedPath), 'report.txt (1)');
    expect(await existing.readAsString(), 'keep this file');
    expect(await File(extractedPath).readAsString(), 'new content');
  });

  test('rejects ZIP entries that escape the extraction directory', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('../outside.txt', 7, 'outside'.codeUnits));
    final archivePath = p.join(tempDirectory.path, 'unsafe.zip');
    await File(archivePath).writeAsBytes(ZipEncoder().encode(archive));

    await expectLater(
      fileSystem.extractZip(archivePath),
      throwsFormatException,
    );
    expect(await File(p.join(tempDirectory.path, 'outside.txt')).exists(), isFalse);
  });

  test('does not overwrite existing archives or extraction folders', () async {
    final source = File(p.join(tempDirectory.path, 'source.txt'));
    await source.writeAsString('source');
    final archivePath = p.join(tempDirectory.path, 'source.zip');
    final existingArchive = File(archivePath);
    await existingArchive.writeAsString('keep archive');

    await expectLater(
      fileSystem.compressToZip([source.path], archivePath),
      throwsA(isA<FileSystemException>()),
    );
    expect(await existingArchive.readAsString(), 'keep archive');

    final extractionPath = Directory(p.join(tempDirectory.path, 'bundle'));
    await extractionPath.create();
    final marker = File(p.join(extractionPath.path, 'marker.txt'));
    await marker.writeAsString('keep folder');
    final bundlePath = p.join(tempDirectory.path, 'bundle.zip');
    final bundle = Archive()
      ..addFile(ArchiveFile('item.txt', 4, 'data'.codeUnits));
    await File(bundlePath).writeAsBytes(ZipEncoder().encode(bundle));

    final extractedPath = await fileSystem.extractZip(bundlePath);
    expect(await marker.readAsString(), 'keep folder');
    expect(p.basename(extractedPath), 'bundle (1)');
    expect(
      await File(p.join(extractedPath, 'item.txt')).readAsString(),
      'data',
    );
  });
}
