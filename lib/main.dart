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
  Locale _locale = const Locale('fr');

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _changeLanguage(String langCode) {
    setState(() {
      _locale = Locale(langCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      locale: _locale,
      home: MainFileManagerScreen(
        onThemeChanged: _changeTheme,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }
}

class MainFileManagerScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;

  const MainFileManagerScreen({
    super.key,
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
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Colors.amber),
            SizedBox(width: 8),
            Text('Körün v0.3.0', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showTrees ? Icons.account_tree : Icons.account_tree_outlined),
            tooltip: 'Basculer les arborescences',
            onPressed: () {
              setState(() {
                _showTrees = !_showTrees;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'fr', child: Text('Français')),
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'tr', child: Text('Türkçe')),
              PopupMenuItem(value: 'ar', child: Text('العربية')),
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
          // Double panneau
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: FilePanelWidget(
                    currentPath: _leftPath,
                    showTree: _showTrees,
                    onFileSelected: (path) => setState(() => _selectedFilePath = path),
                    onPathChanged: (path) => setState(() => _leftPath = path),
                  ),
                ),
                const VerticalDivider(width: 2, thickness: 2),
                Expanded(
                  child: FilePanelWidget(
                    currentPath: _rightPath,
                    showTree: _showTrees,
                    onFileSelected: (path) => setState(() => _selectedFilePath = path),
                    onPathChanged: (path) => setState(() => _rightPath = path),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 2, thickness: 2),
          // Volet d'aperçu
          Expanded(
            flex: 1,
            child: PreviewPanelWidget(filePath: _selectedFilePath),
          ),
        ],
      ),
    );
  }
}

class FilePanelWidget extends StatelessWidget {
  final String currentPath;
  final bool showTree;
  final ValueChanged<String> onFileSelected;
  final ValueChanged<String> onPathChanged;

  const FilePanelWidget({
    super.key,
    required this.currentPath,
    required this.showTree,
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

    return Column(
      children: [
        // Navigation bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: onPathChanged,
                ),
              ),
            ],
          ),
        ),
        // Liste des fichiers
        Expanded(
          child: ListView.builder(
            itemCount: entities.length,
            itemBuilder: (context, index) {
              final entity = entities[index];
              final isDir = FileSystemEntity.isDirectorySync(entity.path);
              return ListTile(
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
                onLongPress: () => _showTimestampDialog(context, entity.path),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTimestampDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📅 Modifier les horodatages'),
        content: Text('Modification des dates pour :\n${p.basename(filePath)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Horodatages mis à jour !')),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class PreviewPanelWidget extends StatelessWidget {
  final String? filePath;

  const PreviewPanelWidget({super.key, this.filePath});

  @override
  Widget build(BuildContext context) {
    if (filePath == null) {
      return const Center(
        child: Text('Sélectionnez un fichier pour afficher son aperçu.'),
      );
    }

    final ext = p.extension(filePath!).toLowerCase();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            'Aperçu : ${p.basename(filePath!)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Center(
            child: Text('Rendu de l\'aperçu pour le fichier ($ext)'),
          ),
        ),
      ],
    );
  }
}
