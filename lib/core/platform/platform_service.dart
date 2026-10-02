import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:path/path.dart' as p;

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
  Future<String> createDesktopShortcut(String targetPath);
  Future<void> composeEmail(List<String> attachments);
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

    final directoryName = _defaultDirectoryName(folder);
    final fallback = '$homePath/$directoryName';
    return await Directory(fallback).exists() ? fallback : null;
  }

  @override
  Future<List<String>> searchRoots() async => ['/'];

  @override
  Future<String> createDesktopShortcut(String targetPath) async {
    final desktop = await getQuickFolderPath(QuickFolder.desktop);
    if (desktop == null) {
      throw FileSystemException('Desktop directory was not found.');
    }
    final shortcutPath = await _uniqueShortcutPath(
      desktop,
      p.basename(targetPath),
    );
    await Link(shortcutPath).create(targetPath);
    return shortcutPath;
  }

  @override
  Future<void> composeEmail(List<String> attachments) async {
    if (attachments.isEmpty) {
      throw ArgumentError('At least one attachment is required.');
    }
    final arguments = <String>[];
    for (final path in attachments) {
      arguments.addAll(['--attach', path]);
    }
    await Process.start('xdg-email', arguments);
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
  Future<String> createDesktopShortcut(String targetPath) async {
    final desktop = await getQuickFolderPath(QuickFolder.desktop);
    if (desktop == null) {
      throw FileSystemException('Desktop directory was not found.');
    }
    final shortcutPath = await _uniqueShortcutPath(
      desktop,
      '${p.basename(targetPath)}.lnk',
    );
    final script = '''
\$shell = New-Object -ComObject WScript.Shell
\$shortcut = \$shell.CreateShortcut(${_psQuote(shortcutPath)})
\$shortcut.TargetPath = ${_psQuote(targetPath)}
\$shortcut.Save()
''';
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    if (result.exitCode != 0 || !await File(shortcutPath).exists()) {
      throw ProcessException(
        'powershell.exe',
        const [],
        '${result.stderr}',
        result.exitCode,
      );
    }
    return shortcutPath;
  }

  @override
  Future<void> composeEmail(List<String> attachments) async {
    if (attachments.isEmpty) {
      throw ArgumentError('At least one attachment is required.');
    }
    final association = await Process.run(
      'reg.exe',
      [
        'query',
        r'HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\mailto\UserChoice',
        '/v',
        'ProgId',
      ],
    );
    final progId = '${association.stdout}'.toLowerCase();
    if (progId.contains('thunderbird')) {
      final executable = await _findWindowsExecutable(
        'thunderbird.exe',
        [
          r'C:\Program Files\Mozilla Thunderbird\thunderbird.exe',
          r'C:\Program Files (x86)\Mozilla Thunderbird\thunderbird.exe',
        ],
      );
      final uris = attachments.map((path) => Uri.file(path).toString()).join(',');
      await Process.start(
        executable,
        ['-compose', "attachment='$uris'"],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    if (progId.contains('outlook')) {
      final pathsJson = base64Encode(utf8.encode(jsonEncode(attachments)));
      final script = '''
\$paths = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$pathsJson')) | ConvertFrom-Json
\$outlook = New-Object -ComObject Outlook.Application
\$message = \$outlook.CreateItem(0)
foreach (\$path in \$paths) { \$null = \$message.Attachments.Add([string]\$path) }
\$message.Display()
''';
      await Process.start(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    throw UnsupportedError(
      'The default mail client does not expose a supported attachment '
      'compose command. Select classic Outlook or Thunderbird as the default '
      'mailto application.',
    );
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

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

Future<String> _uniqueShortcutPath(String directory, String name) async {
  final extension = p.extension(name);
  final base = extension.isEmpty ? name : p.basenameWithoutExtension(name);
  var candidate = p.join(directory, name);
  var suffix = 1;
  while (await FileSystemEntity.type(candidate, followLinks: false) !=
      FileSystemEntityType.notFound) {
    candidate = p.join(directory, '$base ($suffix)$extension');
    suffix++;
  }
  return candidate;
}

Future<String> _findWindowsExecutable(
  String executable,
  List<String> fallbackPaths,
) async {
  final lookup = await Process.run('where.exe', [executable]);
  if (lookup.exitCode == 0) {
    final paths = '${lookup.stdout}'
        .split(RegExp(r'\r?\n'))
        .where((path) => path.trim().isNotEmpty);
    if (paths.isNotEmpty) return paths.first.trim();
  }
  for (final path in fallbackPaths) {
    if (await File(path).exists()) return path;
  }
  throw FileSystemException('Mail application was not found.', executable);
}

PlatformService createPlatformService() =>
    Platform.isWindows ? WindowsService() : LinuxService();
