import 'dart:io';
import 'dart:async';

enum QuickFolder { desktop, downloads, videos, pictures, documents, music }

extension QuickFolderLocalization on QuickFolder {
  String get localizationKey => switch (this) {
        QuickFolder.desktop => 'desktop',
        QuickFolder.downloads => 'downloads',
        QuickFolder.videos => 'videos',
        QuickFolder.pictures => 'pictures',
        QuickFolder.documents => 'documents',
        QuickFolder.music => 'music',
      };
}

abstract class PlatformService {
  String get homePath;
  Future<String?> getQuickFolderPath(QuickFolder folder);
  Future<List<String>> searchRoots();
  bool isHidden(String path);
  Future<void> openExternal(String path);
  List<String> get snapshotRoots;
}

class LinuxService implements PlatformService {
  @override
  String get homePath => Platform.environment['HOME'] ?? '/';

  @override
  Future<String?> getQuickFolderPath(QuickFolder folder) async {
    const xdgNames = {
      QuickFolder.desktop: 'DESKTOP',
      QuickFolder.downloads: 'DOWNLOAD',
      QuickFolder.videos: 'VIDEOS',
      QuickFolder.pictures: 'PICTURES',
      QuickFolder.documents: 'DOCUMENTS',
      QuickFolder.music: 'MUSIC',
    };
    final configDirectory =
        Platform.environment['XDG_CONFIG_HOME'] ?? '$homePath/.config';
    final configFile = File('$configDirectory/user-dirs.dirs');
    if (await configFile.exists()) {
      final key = xdgNames[folder]!;
      for (final line in await configFile.readAsLines()) {
        final match = RegExp('^XDG_${key}_DIR="(.*)"\$').firstMatch(line);
        if (match == null) continue;
        final configured = match.group(1)!
            .replaceAll(r'$HOME', homePath)
            .replaceAll(r'${HOME}', homePath);
        if (await Directory(configured).exists()) return configured;
      }
    }

    @override
    Future<List<String>> searchRoots() async => ['/'];

    final directoryName = _defaultDirectoryName(folder);
    final fallback = '$homePath/$directoryName';
    return await Directory(fallback).exists() ? fallback : null;
  }

  @override
  bool isHidden(String path) => path.split('/').last.startsWith('.');

  @override
  Future<void> openExternal(String path) => Process.start(
    'xdg-open', [path], mode: ProcessStartMode.detached,
  );

  @override
  List<String> get snapshotRoots => ['/.snapshots', '/timeshift/snapshots'];
}

class WindowsService implements PlatformService {
  @override
  String get homePath => Platform.environment['USERPROFILE'] ?? r'C:\';

  @override
  Future<String?> getQuickFolderPath(QuickFolder folder) async {
    final directoryName = _defaultDirectoryName(folder);
    final candidates = <String>[];
    final oneDriveVariables = [
      Platform.environment['OneDriveCommercial'],
      Platform.environment['OneDrive'],
    ];
    for (final oneDrive in oneDriveVariables) {
      if (oneDrive != null) candidates.add('$oneDrive\\$directoryName');
    }
    candidates.add('$homePath\\$directoryName');
    for (final path in candidates.toSet()) {
      if (await Directory(path).exists()) return path;
    }
    return null;
  }

  @override
  Future<List<String>> searchRoots() async {
    final roots = await Future.wait(
      List.generate(26, (index) async {
        final path = '${String.fromCharCode(65 + index)}:\\';
        try {
          return await Directory(path)
                  .exists()
                  .timeout(const Duration(seconds: 2), onTimeout: () => false)
              ? path
              : null;
        } on FileSystemException {
          return null;
        }
      }),
    );
    return roots.whereType<String>().toList();
  }

  @override
  bool isHidden(String path) => false; // TODO: win32 GetFileAttributes

  @override
  Future<void> openExternal(String path) => Process.start(
    'cmd', ['/c', 'start', '', '"$path"'], mode: ProcessStartMode.detached,
  );

  @override
  List<String> get snapshotRoots => const []; // TODO: VSS
}

String _defaultDirectoryName(QuickFolder folder) => switch (folder) {
      QuickFolder.desktop => 'Desktop',
      QuickFolder.downloads => 'Downloads',
      QuickFolder.videos => 'Videos',
      QuickFolder.pictures => 'Pictures',
      QuickFolder.documents => 'Documents',
      QuickFolder.music => 'Music',
    };

PlatformService createPlatformService() =>
    Platform.isWindows ? WindowsService() : LinuxService();
