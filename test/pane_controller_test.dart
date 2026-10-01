import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:korun/features/files/data/services/file_system_service.dart';
import 'package:korun/features/files/state/pane_controller.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late PaneController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('korun_pane_test_');
    await File(p.join(tempDirectory.path, 'one.txt')).writeAsString('one');
    await File(p.join(tempDirectory.path, 'two.txt')).writeAsString('two');
    controller = PaneController(
      FileSystemService(),
      initialPath: tempDirectory.path,
    );
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    await tempDirectory.delete(recursive: true);
  });

  test('Ctrl-style toggling keeps selected item and set in sync', () {
    final first = controller.entries.first;
    final second = controller.entries.last;

    controller.selectOnly(first);
    controller.toggleSelect(second.path);
    expect(controller.selectedEntries, hasLength(2));
    expect(controller.selected?.path, second.path);

    controller.toggleSelect(second.path);
    expect(controller.selectedEntries, hasLength(1));
    expect(controller.selected?.path, first.path);

    controller.toggleSelect(first.path);
    expect(controller.selectedEntries, isEmpty);
    expect(controller.selected, isNull);
  });

  test('clearing selection and reloading clear the preview selection', () async {
    controller.selectOnly(controller.entries.first);
    controller.clearSelection();
    expect(controller.selected, isNull);
    expect(controller.selection, isEmpty);

    controller.selectOnly(controller.entries.first);
    await controller.refresh();
    expect(controller.selected, isNull);
    expect(controller.selection, isEmpty);
  });

  test('directory listing failures remain visible in controller state', () async {
    final missingPath = p.join(tempDirectory.path, 'missing');
    final failedController = PaneController(
      FileSystemService(),
      initialPath: missingPath,
    );
    addTearDown(failedController.dispose);

    await failedController.load();

    expect(failedController.error, isNotNull);
    expect(failedController.entries, isEmpty);
    expect(failedController.loading, isFalse);
  });
}
