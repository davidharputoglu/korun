import 'package:flutter_test/flutter_test.dart';
import 'package:korun/core/i18n/l10n.dart';
import 'package:korun/features/settings/ui/license_translation.dart';

void main() {
  const mit =
      'Permission is hereby granted, free of charge, to any person obtaining a copy';
  const bsd = '''
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
Neither the name of the copyright holder nor the names of its contributors may
be used to endorse or promote products derived from this software.
''';

  test('provides MIT and BSD translations for every non-English locale', () {
    for (final locale in L10n.supported.where((locale) => locale.languageCode != 'en')) {
      final language = locale.languageCode;
      expect(indicativeLicenseTranslation(mit, language), isNotNull);
      expect(indicativeLicenseTranslation(bsd, language), isNotNull);
      expect(licenseTranslationLabel(language, 'warning'), isNotEmpty);
      expect(licenseTranslationLabel(language, 'original'), isNotEmpty);
      expect(korunMitTranslation(language), contains('Copyright (c) 2026'));
    }
  });

  test('does not invent translations for unrecognized licenses', () {
    expect(
      indicativeLicenseTranslation('Unrecognized license terms', 'fr'),
      isNull,
    );
  });
}
