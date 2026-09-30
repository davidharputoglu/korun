import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const KorunApp());
}

class KorunApp extends StatefulWidget {
  const KorunApp({super.key});

  @override
  State<KorunApp> createState() => _KorunAppState();
}

class _KorunAppState extends State<KorunApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  String _currentLang = 'FR';

  void _changeTheme(ThemeMode mode) => setState(() => _themeMode = mode);
  void _changeLanguage(String langCode) => setState(() => _currentLang = langCode);

  @override
  Widget build(BuildContext context) {
    bool isRtl = _currentLang == 'AR';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: MaterialApp(
        title: 'Körün v0.4.0',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
        home: MainFileManagerScreen(
          currentLang: _currentLang,
          onThemeChanged: _changeTheme,
          onLanguageChanged: _changeLanguage,
        ),
      ),
    );
  }
}

const Map<String, Map<String, String>> localizedStrings = {
  'FR': {
    'title': 'Körün — Gestionnaire de fichiers',
    'preview': 'Aperçu',
    'select_file': 'Sélectionnez un fichier',
    'edit_dates': 'Modifier les dates',
    'save': 'Enregistrer',
    'cancel': 'Annuler',
    'success': 'Horodatages mis à jour !',
    'root': 'Disques / Racine',
    'home': 'Dossier Utilisateur',
    'shadow_versions': 'Versions antérieures (VSS / Snapshots)',
    'restore': 'Restaurer cette version',
    'no_shadows': 'Aucun cliché instantané (VSS / Btrfs / Timeshift) trouvé pour ce fichier.',
    'settings': 'Paramètres & Disclaimer',
    'disclaimer': 'Körün v0.4.0 — Logiciel fourni tel quel. L\'utilisateur est responsable des modifications d\'horodatage et de restauration.'
  },
  'EN': {
    'title': 'Körün — File Manager',
    'preview': 'Preview',
    'select_file': 'Select a file to preview',
    'edit_dates': 'Edit Timestamps',
    'save': 'Save',
    'cancel': 'Cancel',
    'success': 'Timestamps updated!',
    'root': 'Drives / Root',
    'home': 'User Folder',
    'shadow_versions': 'Previous Versions (VSS / Snapshots)',
    'restore': 'Restore this version',
    'no_shadows': 'No Shadow Copies / Snapshots found for this file.',
    'settings': 'Settings & Disclaimer',
    'disclaimer': 'Körün v0.4.0 — Software provided as is. User assumes responsibility for timestamp and file restorations.'
  },
  'AR': {
    'title': 'Körün — مدير الملفات',
    'preview': 'معاينة',
    'select_file': 'حدد ملفا للمعاينة',
    'edit_dates': 'تعديل التواريخ',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'success': 'تم تحديث التواريخ!',
    'root': 'الأقراص / الجذر',
    'home': 'مجلد المستخدم',
    'shadow_versions': 'النسخ السابقة (VSS / Snapshots)',
    'restore': 'استعادة هذه النسخة',
    'no_shadows': 'لم يتم العثور على نسخ استعادة لهذا الملف.',
    'settings': 'الإعدادات والإخلاء',
    'disclaimer': 'Körün v0.4.0 — البرنامج مقدم كما هو. يتحمل المستخدم المسؤولية الكاملة عن تعديل التواريخ واستعادة الملفات.'
  },
  'TR': {
    'title': 'Körün — Dosya Yöneticisi',
    'preview': 'Önizleme',
    'select_file': 'Önizlemek için dosya seçin',
    'edit_dates': 'Tarihleri Düzenle',
    'save': 'Kaydet',
    'cancel': 'İptal',
    'success': 'Zaman damgaları güncellendi!',
    'root': 'Sürücüler / Kök',
    'home': 'Kullanıcı Klasörü',
    'shadow_versions': 'Önceki Sürümler (VSS / Anlık Görüntü)',
    'restore': 'Bu sürümü geri yükle',
    'no_shadows': 'Bu dosya için anlık görüntü (VSS / Btrfs) bulunamadı.',
    'settings': 'Ayarlar ve Sorumluluk Reddi',
    'disclaimer': 'Körün v0.4.0 — Yazılım olduğu gibi sunulmaktadır. Zaman damgası ve dosya kurtarma sorumluluğu kullanıcıya aittir.'
  }
};

class MainFileManagerScreen extends StatefulWidget {
  final String currentLang;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;

  const MainFileManagerScreen({super.key, required this.currentLang, required this.onThemeChanged, required this.onLanguageChanged});

  @override
  State<MainFileManagerScreen> createState() => _MainFileManagerScreenState();
}

class _MainFileManagerScreenState extends State<MainFileManagerScreen> {
  String _leftPath = Directory.current.path;
  String _rightPath = Directory.current.path;
  String? _selectedFilePath;
  bool _showTrees = true;

  @override
  Widget build(BuildContext context) {
    final t = localizedStrings[widget.currentLang] ?? localizedStrings['FR']!;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset('assets/icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.folder_special, color: Colors.amber)),
        ),
        title: Text('${t['title']} (v0.4.0)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        actions: [
          IconButton(
            icon: Icon(_showTrees ? Icons.account_tree : Icons.account_tree_outlined),
            tooltip: 'Arborescences',
            onPressed: () => setState(() => _showTrees = !_showTrees),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: t['settings'],
            onPressed: () => _showSettingsDialog(context, t),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'FR', child: Text('Français (FR)')),
              PopupMenuItem(value: 'EN', child: Text('English (EN)')),
              PopupMenuItem(value: 'TR', child: Text('Türkçe (TR)')),
              PopupMenuItem(value: 'AR', child: Text('العربية (AR)')),
            ],
          ),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.palette),
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Clair')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(child: FilePanelWidget(currentPath: _leftPath, showTree: _showTrees, lang: widget.currentLang, onFileSelected: (p) => setState(() => _selectedFilePath = p), onPathChanged: (p) => setState(() => _leftPath = p))),
                const VerticalDivider(width: 2, thickness: 2),
                Expanded(child: FilePanelWidget(currentPath: _rightPath, showTree: _showTrees, lang: widget.currentLang, onFileSelected: (p) => setState(() => _selectedFilePath = p), onPathChanged: (p) => setState(() => _rightPath = p))),
              ],
            ),
          ),
          const VerticalDivider(width: 2, thickness: 2),
          Expanded(flex: 2, child: PreviewPanelWidget(filePath: _selectedFilePath, lang: widget.currentLang)),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, Map<String, String> t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t['settings']!),
        content: Text(t['disclaimer']!),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class FilePanelWidget extends StatelessWidget {
  final String currentPath;
  final bool showTree;
  final String lang;
  final ValueChanged<String> onFileSelected;
  final ValueChanged<String> onPathChanged;

  const FilePanelWidget({super.key, required this.currentPath, required this.showTree, required this.lang, required this.onFileSelected, required this.onPathChanged});

  @override
  Widget build(BuildContext context) {
    final t = localizedStrings[lang] ?? localizedStrings['FR']!;
    final isWindows = Platform.isWindows;
    final dir = Directory(currentPath);
    List<FileSystemEntity> entities = [];
    if (dir.existsSync()) {
      try { entities = dir.listSync(); } catch (_) {}
    }

    return Row(
      children: [
        if (showTree)
          Container(
            width: 160,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: ListView(
              children: [
                ListTile(
                  dense: true,
                  title: Text(isWindows ? '💻 C:\\' : '📁 ${t['root']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => onPathChanged(isWindows ? 'C:\\' : '/'),
                ),
                ListTile(
                  dense: true,
                  title: Text('🏠 ${t['home']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    final home = isWindows ? Platform.environment['USERPROFILE'] ?? 'C:\\' : Platform.environment['HOME'] ?? '/';
                    onPathChanged(home);
                  },
                ),
              ],
            ),
          ),
        if (showTree) const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_upward, size: 18), onPressed: () {
                      final parent = p.dirname(currentPath);
                      if (parent != currentPath) onPathChanged(parent);
                    }),
                    Expanded(child: TextField(controller: TextEditingController(text: currentPath), decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)), onSubmitted: onPathChanged)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (_, index) {
                    final entity = entities[index];
                    final isDir = FileSystemEntity.isDirectorySync(entity.path);
                    return ListTile(
                      dense: true,
                      leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file, color: isDir ? Colors.amber : Colors.lightBlue),
                      title: Text(p.basename(entity.path)),
                      onTap: () => isDir ? onPathChanged(entity.path) : onFileSelected(entity.path),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isDir)
                            IconButton(
                              icon: const Icon(Icons.history, size: 18, color: Colors.purpleAccent),
                              tooltip: t['shadow_versions'],
                              onPressed: () => showDialog(context: context, builder: (_) => ShadowExplorerDialog(filePath: entity.path, lang: lang)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            tooltip: t['edit_dates'],
                            onPressed: () => showDialog(context: context, builder: (_) => TimestampDialog(filePath: entity.path, lang: lang)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShadowExplorerDialog extends StatefulWidget {
  final String filePath;
  final String lang;
  const ShadowExplorerDialog({super.key, required this.filePath, required this.lang});

  @override
  State<ShadowExplorerDialog> createState() => _ShadowExplorerDialogState();
}

class _ShadowExplorerDialogState extends State<ShadowExplorerDialog> {
  List<String> _foundSnapshots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchSnapshots();
  }

  Future<void> _searchSnapshots() async {
    List<String> snapshots = [];
    try {
      if (Platform.isLinux) {
        final snapshotDirs = [
          '/.snapshots',
          '/timeshift/snapshots',
          '${Platform.environment['HOME']}/.snapshots',
        ];
        final filename = p.basename(widget.filePath);

        for (var sDir in snapshotDirs) {
          final dir = Directory(sDir);
          if (dir.existsSync()) {
            final entries = dir.listSync();
            for (var entry in entries) {
              final candidate = File(p.join(entry.path, filename));
              if (candidate.existsSync()) {
                snapshots.add(candidate.path);
              }
            }
          }
        }
      }
    } catch (_) {}

    setState(() {
      _foundSnapshots = snapshots;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = localizedStrings[widget.lang] ?? localizedStrings['FR']!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: Colors.purpleAccent),
          const SizedBox(width: 8),
          Text(t['shadow_versions']!),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fichier : ${p.basename(widget.filePath)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_foundSnapshots.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black25, borderRadius: BorderRadius.circular(8)),
                child: Text(t['no_shadows']!),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _foundSnapshots.length,
                  itemBuilder: (_, index) {
                    final snapPath = _foundSnapshots[index];
                    final stat = FileStat.statSync(snapPath);
                    return ListTile(
                      dense: true,
                      title: Text(snapPath, style: const TextStyle(fontSize: 12)),
                      subtitle: Text('Date : ${stat.modified}'),
                      trailing: ElevatedButton(
                        child: Text(t['restore']!),
                        onPressed: () {
                          try {
                            File(snapPath).copySync(widget.filePath);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fichier restauré avec succès !')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur : $e')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t['cancel']!)),
      ],
    );
  }
}

class TimestampDialog extends StatefulWidget {
  final String filePath;
  final String lang;
  const TimestampDialog({super.key, required this.filePath, required this.lang});

  @override
  State<TimestampDialog> createState() => _TimestampDialogState();
}

class _TimestampDialogState extends State<TimestampDialog> {
  late DateTime _mtime;
  late DateTime _atime;

  @override
  void initState() {
    super.initState();
    final stat = FileStat.statSync(widget.filePath);
    _mtime = stat.modified;
    _atime = stat.accessed;
  }

  Future<void> _pickDateTime(bool isMtime) async {
    final initialDate = isMtime ? _mtime : _atime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2099),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (isMtime) {
            _mtime = newDateTime;
          } else {
            _atime = newDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = localizedStrings[widget.lang] ?? localizedStrings['FR']!;
    return AlertDialog(
      title: Text(t['edit_dates']!),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fichier : ${p.basename(widget.filePath)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Modification : $_mtime'),
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month, size: 16),
            onPressed: () => _pickDateTime(true),
            label: const Text('Choisir Date & Heure (Modification)'),
          ),
          const SizedBox(height: 8),
          Text('Accès : $_atime'),
          ElevatedButton.icon(
            icon: const Icon(Icons.access_time, size: 16),
            onPressed: () => _pickDateTime(false),
            label: const Text('Choisir Date & Heure (Accès)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t['cancel']!)),
        ElevatedButton(onPressed: () {
          try {
            File(widget.filePath).setLastModifiedSync(_mtime);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['success']!)));
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
          }
        }, child: Text(t['save']!)),
      ],
    );
  }
}

class PreviewPanelWidget extends StatelessWidget {
  final String? filePath;
  final String lang;
  const PreviewPanelWidget({super.key, this.filePath, required this.lang});

  @override
  Widget build(BuildContext context) {
    final t = localizedStrings[lang] ?? localizedStrings['FR']!;
    if (filePath == null) {
      return Center(child: Text(t['select_file']!, textAlign: TextAlign.center));
    }
    final ext = p.extension(filePath!).toLowerCase();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text('${t['preview']} : ${p.basename(filePath!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Center(child: Text('Type : $ext'))),
      ],
    );
  }
}