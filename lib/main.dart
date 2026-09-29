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

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _changeLanguage(String langCode) {
    setState(() {
      _currentLang = langCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _currentLang == 'AR';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: MaterialApp(
        title: 'Körün',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        home: MainFileManagerScreen(
          currentLang: _currentLang,
          onThemeChanged: _changeTheme,
          onLanguageChanged: _changeLanguage,
        ),
      ),
    );
  }
}

class MainFileManagerScreen extends StatefulWidget {
  final String currentLang;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;

  const MainFileManagerScreen({
    super.key,
    required this.currentLang,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

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
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset('assets/icon.png', errorBuilder: (context, error, stackTrace) => const Icon(Icons.folder_special, color: Colors.amber)),
        ),
        title: Text('Körün v0.3.2 — ${widget.currentLang}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_showTrees ? Icons.account_tree : Icons.account_tree_outlined),
            tooltip: 'Basculer les arborescences',
            onPressed: () => setState(() => _showTrees = !_showTrees),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'FR', child: Text('Français (FR)')),
              PopupMenuItem(value: 'EN', child: Text('English (EN)')),
              PopupMenuItem(value: 'TR', child: Text('Türkçe (TR)')),
              PopupMenuItem(value: 'AR', child: Text('العربية (AR)')),
              PopupMenuItem(value: 'AZ', child: Text('Azərbaycan (AZ)')),
              PopupMenuItem(value: 'KK', child: Text('Қазақша (KK)')),
              PopupMenuItem(value: 'UZ', child: Text('Oʻzbekcha (UZ)')),
              PopupMenuItem(value: 'TK', child: Text('Türkmençe (TK)')),
              PopupMenuItem(value: 'KY', child: Text('Кыргызча (KY)')),
              PopupMenuItem(value: 'IT', child: Text('Italiano (IT)')),
              PopupMenuItem(value: 'ES', child: Text('Español (ES)')),
              PopupMenuItem(value: 'PT', child: Text('Português (PT)')),
            ],
          ),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.palette),
            onSelected: widget.onThemeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.dark, child: Text('Sombre (Catppuccin)')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Clair (Material)')),
              PopupMenuItem(value: ThemeMode.system, child: Text('Système')),
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
                Expanded(
                  child: FilePanelWidget(
                    currentPath: _leftPath,
                    showTree: _showTrees,
                    lang: widget.currentLang,
                    onFileSelected: (path) => setState(() => _selectedFilePath = path),
                    onPathChanged: (path) => setState(() => _leftPath = path),
                  ),
                ),
                const VerticalDivider(width: 2, thickness: 2),
                Expanded(
                  child: FilePanelWidget(
                    currentPath: _rightPath,
                    showTree: _showTrees,
                    lang: widget.currentLang,
                    onFileSelected: (path) => setState(() => _selectedFilePath = path),
                    onPathChanged: (path) => setState(() => _rightPath = path),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 2, thickness: 2),
          Expanded(
            flex: 2,
            child: PreviewPanelWidget(filePath: _selectedFilePath, lang: widget.currentLang),
          ),
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

  const FilePanelWidget({
    super.key,
    required this.currentPath,
    required this.showTree,
    required this.lang,
    required this.onFileSelected,
    required this.onPathChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dir = Directory(currentPath);
    List<FileSystemEntity> entities = [];
    if (dir.existsSync()) {
      try {
        entities = dir.listSync();
      } catch (_) {}
    }

    return Row(
      children: [
        if (showTree)
          Container(
            width: 150,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: ListView(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Racine /', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => onPathChanged(Directory.systemTemp.parent.path),
                ),
                ListTile(
                  dense: true,
                  title: const Text('🏠 Home', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => onPathChanged(Directory.current.path),
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
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: () {
                        final parent = p.dirname(currentPath);
                        if (parent != currentPath) onPathChanged(parent);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: currentPath),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onSubmitted: onPathChanged,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    final isDir = FileSystemEntity.isDirectorySync(entity.path);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isDir ? Icons.folder : Icons.insert_drive_file,
                        color: isDir ? Colors.amber : Colors.lightBlue,
                      ),
                      title: Text(p.basename(entity.path)),
                      onTap: () {
                        if (isDir) {
                          onPathChanged(entity.path);
                        } else {
                          onFileSelected(entity.path);
                        }
                      },
                      onLongPress: () => _openTimestampDialog(context, entity.path),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        tooltip: 'Modifier les dates',
                        onPressed: () => _openTimestampDialog(context, entity.path),
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

  void _openTimestampDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => TimestampDialog(filePath: filePath, lang: lang),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lang == 'FR' ? '📅 Modifier les dates' : '📅 Edit Timestamps'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fichier : ${p.basename(widget.filePath)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Modification : ${_mtime.toLocal()}'),
          ElevatedButton(
            onPressed: () async {
              setState(() => _mtime = DateTime.now());
            },
            child: const Text('Mettre à l\'heure actuelle (Modification)'),
          ),
          const SizedBox(height: 8),
          Text('Accès : ${_atime.toLocal()}'),
          ElevatedButton(
            onPressed: () async {
              setState(() => _atime = DateTime.now());
            },
            child: const Text('Mettre à l\'heure actuelle (Accès)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.lang == 'FR' ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            try {
              // Correction ici : utilisation directe de widget.filePath
              File(widget.filePath).setLastModifiedSync(_mtime);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.lang == 'FR' ? 'Horodatages mis à jour avec succès !' : 'Timestamps updated successfully!')),
              );
            } catch (e) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur : $e')),
              );
            }
          },
          child: Text(widget.lang == 'FR' ? 'Enregistrer' : 'Save'),
        ),
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
    if (filePath == null) {
      return Center(
        child: Text(
          lang == 'FR' ? 'Sélectionnez un fichier pour afficher son aperçu.' : 'Select a file to preview.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final ext = p.extension(filePath!).toLowerCase();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '${lang == 'FR' ? 'Aperçu' : 'Preview'} : ${p.basename(filePath!)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Center(
            child: Text('${lang == 'FR' ? 'Type de fichier' : 'File type'} : $ext'),
          ),
        ),
      ],
    );
  }
}
