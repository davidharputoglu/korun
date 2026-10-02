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
  const archiveDialogKeys = [
    'compress',
    'archive_name',
    'archive_created',
    'archive_format',
    'compression_method',
    'compression_method_korun',
    'compression_method_7zip',
    'compression_method_winrar',
    'archive_format_zip',
    'archive_format_tar',
    'archive_format_tar_gzip',
    'archive_format_tar_bzip2',
    'archive_format_tar_xz',
    'archive_format_7z',
    'archive_format_rar',
    'archive_format_gzip',
    'archive_format_bzip2',
    'archive_format_xz',
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

  test('archive creation dialog strings are translated in every language', () {
    for (final locale in L10n.supported) {
      for (final key in archiveDialogKeys) {
        expect(
          L10n.t(locale, key),
          isNot(key),
          reason: '${locale.languageCode}: $key',
        );
      }
    }
  });
}
