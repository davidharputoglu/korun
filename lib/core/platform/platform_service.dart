import 'dart:io';

abstract class PlatformService {
  String get homePath;
  Future<String?> getDesktopPath();
  bool isHidden(String path);
  Future<void> openExternal(String path);
  List<String> get snapshotRoots;
}

class LinuxService implements PlatformService {
  @override
  String get homePath => Platform.environment['HOME'] ?? '/';

  @override
  Future<String?> getDesktopPath() async {
    final desktop = '${homePath}/Desktop';
    return await Directory(desktop).exists() ? desktop : null;
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
  Future<String?> getDesktopPath() async {
    final candidates = <String>[];
    final commercialOneDrive = Platform.environment['OneDriveCommercial'];
    final oneDrive = Platform.environment['OneDrive'];
    if (commercialOneDrive != null) {
      candidates.add('$commercialOneDrive\\Desktop');
    }
    if (oneDrive != null) candidates.add('$oneDrive\\Desktop');
    candidates.add('$homePath\\Desktop');
    for (final path in candidates.toSet()) {
      if (await Directory(path).exists()) return path;
    }
    return null;
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

PlatformService createPlatformService() =>
    Platform.isWindows ? WindowsService() : LinuxService();
