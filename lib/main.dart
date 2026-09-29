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
        title: 'Körün',
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

// Dictionnaire complet des 12 langues pour les éléments clés de l'interface
const Map<String, Map<String, String>> localizedStrings = {
  'FR': {'title': 'Körün — Gestionnaire de fichiers', 'preview': 'Aperçu', 'select_file': 'Sélectionnez un fichier', 'edit_dates': 'Modifier les dates', 'save': 'Enregistrer', 'cancel': 'Annuler', 'success': 'Horodatages mis à jour !'},
  'EN': {'title': 'Körün — File Manager', 'preview': 'Preview', 'select_file': 'Select a file to preview', 'edit_dates': 'Edit Timestamps', 'save': 'Save', 'cancel': 'Cancel', 'success': 'Timestamps updated!'},
  'TR': {'title': 'Körün — Dosya Yöneticisi', 'preview': 'Önizleme', 'select_file': 'Önizlemek için dosya seçin', 'edit_dates': 'Tarihleri Düzenle', 'save': 'Kaydet', 'cancel': 'İptal', 'success': 'Zaman damgaları güncellendi!'},
  'AR': {'title': 'Körün — مدير الملفات', 'preview': 'معاينة', 'select_file': 'حدد ملفا للمعاينة', 'edit_dates': 'تعديل التواريخ', 'save': 'حفظ', 'cancel': 'إلغاء', 'success': 'تم تحديث التواريخ!'},
  'AZ': {'title': 'Körün — Fayl Meneceri', 'preview': 'İcmal', 'select_file': 'Fayl seçin', 'edit_dates': 'Tarixçəni Dəyiş', 'save': 'Yadda saxla', 'cancel': 'Ləğv et', 'success': 'Uğurla yeniləndi!'},
  'KK': {'title': 'Körün — Файл менеджері', 'preview': 'Қарау', 'select_file': 'Файлды таңдаңыз', 'edit_dates': 'Күндерді өзгерту', 'save': 'Сақтау', 'cancel': 'Болдырмау', 'success': 'Сәтті жаңартылды!'},
  'UZ': {'title': 'Körün — Fayl menejeri', 'preview': 'Ko‘rib chiqish', 'select_file': 'Faylni tanlang', 'edit_dates': 'Sanani o‘zgartirish', 'save': 'Saqlash', 'cancel': 'Bekor qilish', 'success': 'Yangilandi!'},
  'TK': {'title': 'Körün — Faýl dolandyryjysy', 'preview': 'Gözden geçiriş', 'select_file': 'Faýl saýlaň', 'edit_dates': 'Seneleri üýtgetmek', 'save': 'Saklamak', 'cancel': 'Ýatyrmak', 'success': 'Üýtgedildi!'},
  'KY': {'title': 'Körün — Файл менеджери', 'preview': 'Көрүү', 'select_file': 'Файлды тандаңыз', 'edit_dates': 'Датаны өзгөртүү', 'save': 'Сактоо', 'cancel': 'Жокко чыгаруу', 'success': 'Ийгиликтүү жаңыланды!'},
  'IT': {'title': 'Körün — Gestore di file', 'preview': 'Anteprima', 'select_file': 'Seleziona un file', 'edit_dates': 'Modifica date', 'save': 'Salva', 'cancel': 'Annulla', 'success': 'Date aggiornate!'},
  'ES': {'title': 'Körün — Administrador de archivos', 'preview': 'Vista previa', 'select_file': 'Seleccione un archivo', 'edit_dates': 'Editar fechas', 'save': 'Guardar', 'cancel': 'Cancelar', 'success': '¡Fechas actualizadas!'},
  'PT': {'title': 'Körün — Gerenciador de arquivos', 'preview': 'Visualização', 'select_file': 'Selecione um arquivo', 'edit_dates': 'Editar datas', 'save': 'Salvar', 'cancel': 'Cancelar', 'success': 'Datas atualizadas!'},
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
        title: Text('${t['title']} (v0.3.3)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        actions: [
          IconButton(
            icon: Icon(_showTrees ? Icons.account_tree : Icons.account_tree_outlined),
            tooltip: 'Arborescences',
            onPressed: () => setState(() => _showTrees = !_showTrees),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (_) => const [
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
            itemBuilder: (_) => const [
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
    final dir = Directory(currentPath);
    List<FileSystemEntity> entities = [];
    if (dir.existsSync()) {
      try { entities = dir.listSync(); } catch (_) {}
    }

    return Row(
      children: [
        if (showTree)
          Container(
            width: 140,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            child: ListView(
              children: [
                ListTile(dense: true, title: const Text('📁 Racine', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => onPathChanged('/')),
                ListTile(dense: true, title: const Text('🏠 Home', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => onPathChanged(Directory.current.path)),
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
                      trailing: IconButton(icon: const Icon(Icons.edit_calendar, size: 18), tooltip: 'Horodatages', onPressed: () => showDialog(context: context, builder: (_) => TimestampDialog(filePath: entity.path, lang: lang))),
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
          ElevatedButton(onPressed: () => setState(() => _mtime = DateTime.now()), child: const Text('Mettre à l\'heure actuelle')),
          const SizedBox(height: 8),
          Text('Accès : $_atime'),
          ElevatedButton(onPressed: () => setState(() => _atime = DateTime.now()), child: const Text('Mettre à l\'heure actuelle')),
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
