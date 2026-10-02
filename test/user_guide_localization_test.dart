import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:korun/core/i18n/l10n.dart';

void main() {
  const guideKeys = [
    'guide_title',
    'guide_intro',
    'guide_dates_title',
    'guide_dates_body',
    'guide_otken_title',
    'guide_otken_body',
    'guide_show_at_start',
    'guide_button',
    'close',
  ];

  test('user guide strings are translated in every supported language', () {
    for (final locale in L10n.supported) {
      for (final key in guideKeys) {
        final translated = L10n.t(locale, key);
        expect(translated, isNot(key), reason: '${locale.languageCode}: $key');
        if (locale.languageCode != 'en') {
          expect(
            translated,
            isNot(L10n.t(const Locale('en'), key)),
            reason: '${locale.languageCode}: $key fell back to English',
          );
        }
      }
    }
  });
}
