import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/models/file_entry.dart';
import '../data/services/file_system_service.dart';

class PaneController extends ChangeNotifier {
  PaneController(this._fs, {String? initialPath})
      : _current = initialPath ?? '/' {
    _history.add(_current);
  }

  final FileSystemService _fs;
  String _current;
  final List<String> _history = [];
  int _historyIndex = 0;
  List<FileEntry> _entries = const [];
  FileEntry? _selected;
  final Set<String> _selection = {};
  bool _loading = false;
  String? _error;
  bool _showHidden = false;
  SortBy _sortBy = SortBy.name;
  bool _ascending = true;
  ViewMode _viewMode = ViewMode.list;
  int _loadToken = 0;

  String get currentPath => _current;
  List<FileEntry> get entries => _entries;
  FileEntry? get selected => _selected;
  Set<String> get selection => _selection;
  List<FileEntry> get selectedEntries =>
      _entries.where((e) => _selection.contains(e.path)).toList();
  bool get loading => _loading;
  String? get error => _error;
  bool get showHidden => _showHidden;
  SortBy get sortBy => _sortBy;
  bool get ascending => _ascending;
  ViewMode get viewMode => _viewMode;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;

  Future<void> load({bool? showHidden}) async {
    if (showHidden != null) _showHidden = showHidden;
    final token = ++_loadToken;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _fs.listDirectory(
        _current,
        showHidden: _showHidden,
        sortBy: _sortBy,
        ascending: _ascending,
      );
    } catch (error) {
      if (token == _loadToken) {
        _entries = const [];
        _error = error.toString();
      }
    }
    if (token == _loadToken) {
      _selection.clear();
      _selected = null;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> cd(String path) async {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(path);
    _historyIndex = _history.length - 1;
    _current = path;
    _selected = null;
    _selection.clear();
    await load();
  }

  Future<void> goUp() => cd(p.dirname(_current));

  Future<void> back() async {
    if (!canGoBack) return;
    _historyIndex--;
    _current = _history[_historyIndex];
    _selected = null;
    _selection.clear();
    await load();
  }

  Future<void> forward() async {
    if (!canGoForward) return;
    _historyIndex++;
    _current = _history[_historyIndex];
    _selected = null;
    _selection.clear();
    await load();
  }

  Future<void> setSort(SortBy s) async {
    if (_sortBy == s) {
      _ascending = !_ascending;
    } else {
      _sortBy = s;
      _ascending = true;
    }
    await load();
  }

  void setViewMode(ViewMode v) {
    _viewMode = v;
    notifyListeners();
  }

  Future<void> refresh() => load();

  // ---------- Sélection ----------
  void selectOnly(FileEntry e) {
    _selection.clear();
    _selection.add(e.path);
    _selected = e;
    notifyListeners();
  }

  void toggleSelect(String path) {
    if (!_selection.remove(path)) {
      _selection.add(path);
      for (final e in _entries) {
        if (e.path == path) _selected = e;
      }
    } else if (_selected?.path == path) {
      _selected = null;
      for (final entry in _entries) {
        if (_selection.contains(entry.path)) _selected = entry;
      }
    }
    notifyListeners();
  }

  void rangeSelect(String from, String to) {
    var a = -1, b = -1;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].path == from) a = i;
      if (_entries[i].path == to) b = i;
    }
    if (a < 0 || b < 0) return;
    if (a > b) { final t = a; a = b; b = t; }
    for (var i = a; i <= b; i++) {
      _selection.add(_entries[i].path);
    }
    _selected = _entries[b];
    notifyListeners();
  }

  void selectAll() {
    _selection.addAll(_entries.map((e) => e.path));
    if (_entries.isNotEmpty) _selected = _entries.first;
    notifyListeners();
  }

  void clearSelection() {
    _selection.clear();
    _selected = null;
    notifyListeners();
  }
}
