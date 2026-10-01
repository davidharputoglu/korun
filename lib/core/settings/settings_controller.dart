import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, oledBlack }

class CustomTheme {
  const CustomTheme({required this.id, required this.name, required this.mode, required this.colorValue});
  final String id;
  final String name;
  final AppThemeMode mode;
  final int colorValue;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mode': mode.index, 'color': colorValue};
  static CustomTheme fromJson(Map<String, dynamic> j) => CustomTheme(
    id: j['id'] as String, name: j['name'] as String,
    mode: AppThemeMode.values[j['mode'] as int],
    colorValue: (j['color'] as num).toInt(),
  );
}

class SettingsController extends ChangeNotifier {
  static const Map<String, Color> presetAccents = {
    'turquoise': Color(0xFF2DD4BF), 'blue': Color(0xFF2196F3),
    'emerald': Color(0xFF50C878), 'purple': Color(0xFF7C4DFF),
    'amber': Color(0xFFFFC107), 'gold': Color(0xFFFFD700),
    'crimson': Color(0xFFEF5350),
  };

  AppThemeMode _mode = AppThemeMode.oledBlack;
  Color _accent = const Color(0xFF2DD4BF);
  String _activeThemeId = 'preset:turquoise';
  List<CustomTheme> _customThemes = [];
  Locale _locale = const Locale('fr');
  bool _showHidden = false;
  bool _showPreviews = true;
  bool _otkenEnabled = true;

  AppThemeMode get mode => _mode;
  Color get accent => _accent;
  String get activeThemeId => _activeThemeId;
  List<CustomTheme> get customThemes => List.unmodifiable(_customThemes);
  Locale get locale => _locale;
  bool get showHidden => _showHidden;
  bool get showPreviews => _showPreviews;
  bool get otkenEnabled => _otkenEnabled;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _mode = AppThemeMode.values[p.getInt('theme.mode') ?? AppThemeMode.oledBlack.index];
    _accent = Color(p.getInt('theme.accent') ?? const Color(0xFF2DD4BF).value);
    _activeThemeId = p.getString('theme.activeId') ?? 'preset:turquoise';
    _customThemes = (p.getStringList('theme.customs') ?? const [])
        .map((s) => CustomTheme.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    _locale = Locale(p.getString('locale') ?? 'fr');
    _showHidden = p.getBool('showHidden') ?? false;
    _showPreviews = p.getBool('showPreviews') ?? true;
    _otkenEnabled = p.getBool('otkenEnabled') ?? true;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode m) => _apply(id: _activeThemeId, color: _accent, mode: m);
  Future<void> applyPreset(String key) => _apply(id: 'preset:$key', color: presetAccents[key]!, mode: _mode);

  Future<void> saveCustomTheme(String name, AppThemeMode m, Color color) async {
    final t = CustomTheme(id: 'custom:${DateTime.now().millisecondsSinceEpoch}', name: name, mode: m, colorValue: color.value);
    _customThemes.add(t);
    await _apply(id: t.id, color: color, mode: m);
  }

  Future<void> applyCustomTheme(String id) async {
    final t = _customThemes.firstWhere((t) => t.id == id);
    await _apply(id: id, color: t.color, mode: t.mode);
  }

  Future<void> deleteCustomTheme(String id) async {
    _customThemes.removeWhere((t) => t.id == id);
    if (_activeThemeId == id) await applyPreset('turquoise');
    else { await _persist(); notifyListeners(); }
  }

  Future<void> setLocale(Locale l) async { _locale = l; notifyListeners(); await _persist(); }
  Future<void> toggleHidden() async { _showHidden = !_showHidden; notifyListeners(); await _persist(); }
  Future<void> setShowPreviews(bool value) async {
    _showPreviews = value;
    notifyListeners();
    await _persist();
  }
  Future<void> setOtkenEnabled(bool value) async {
    _otkenEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> _apply({required String id, required Color color, required AppThemeMode mode}) async {
    _activeThemeId = id; _accent = color; _mode = mode;
    notifyListeners(); await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme.mode', _mode.index);
    await p.setInt('theme.accent', _accent.value);
    await p.setString('theme.activeId', _activeThemeId);
    await p.setStringList('theme.customs', _customThemes.map((t) => jsonEncode(t.toJson())).toList());
    await p.setString('locale', _locale.languageCode);
    await p.setBool('showHidden', _showHidden);
    await p.setBool('showPreviews', _showPreviews);
    await p.setBool('otkenEnabled', _otkenEnabled);
  }

  ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: _mode == AppThemeMode.light ? Brightness.light : Brightness.dark,
      ),
    );
    if (_mode != AppThemeMode.oledBlack) return base;
    return base.copyWith(
      scaffoldBackgroundColor: Colors.black, canvasColor: Colors.black,
      cardColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
    );
  }
}
