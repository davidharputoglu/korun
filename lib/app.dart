import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/i18n/l10n.dart';
import 'core/settings/settings_controller.dart';
import 'features/files/ui/home_page.dart';

/// Secours : locales non couvertes par GlobalMaterialLocalizations
/// (ex. tatar, turkmène) -> Material en anglais au lieu de planter.
/// Nos chaînes (L10n) restent, elles, dans la langue choisie.
class _MaterialFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) =>
      !GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_MaterialFallbackDelegate old) => false;
}

class KorunApp extends StatelessWidget {
  const KorunApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return MaterialApp(
      title: 'Körün',
      debugShowCheckedModeBanner: false,
      theme: s.buildTheme(),
      locale: s.locale,
      supportedLocales: L10n.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        _MaterialFallbackDelegate(),
      ],
      home: const HomePage(),
    );
  }
}
