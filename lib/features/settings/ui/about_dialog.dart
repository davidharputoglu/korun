import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_info.dart';
import '../../../core/i18n/l10n.dart';
import 'license_translation.dart';

const _mitLicenseText = '''
MIT License

Copyright (c) 2026 David Harputoglu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _mitLicenseFrench = '''
Licence MIT — traduction indicative non officielle

Copyright (c) 2026 David Harputoglu

L'autorisation est accordée, gratuitement, à toute personne obtenant une copie
de ce logiciel et des fichiers de documentation associés (le « Logiciel »), de
traiter le Logiciel sans restriction, notamment les droits d'utiliser, copier,
modifier, fusionner, publier, distribuer, sous-licencier et/ou vendre des copies
du Logiciel, et d'autoriser les personnes auxquelles le Logiciel est fourni à
faire de même, sous réserve des conditions suivantes :

La présente notice de droit d'auteur et la présente autorisation doivent être
incluses dans toutes les copies ou parties substantielles du Logiciel.

LE LOGICIEL EST FOURNI « EN L'ÉTAT », SANS GARANTIE D'AUCUNE SORTE, EXPRESSE OU
IMPLICITE, Y COMPRIS, SANS S'Y LIMITER, LES GARANTIES DE QUALITÉ MARCHANDE,
D'ADÉQUATION À UN USAGE PARTICULIER ET D'ABSENCE DE CONTREFAÇON. EN AUCUN CAS
LES AUTEURS OU TITULAIRES DU DROIT D'AUTEUR NE POURRONT ÊTRE TENUS RESPONSABLES
DE TOUTE RÉCLAMATION, DE TOUT DOMMAGE OU DE TOUTE AUTRE RESPONSABILITÉ, QUE CE
SOIT DANS LE CADRE D'UNE ACTION CONTRACTUELLE, DÉLICTUELLE OU AUTRE, DÉCOULANT
DU LOGICIEL OU DE SON UTILISATION, OU EN RELATION AVEC CEUX-CI.
''';

const _mitThirdPartyFrench = '''
Licence MIT — traduction indicative non officielle

L'autorisation est accordée, gratuitement, à toute personne obtenant une copie
de ce logiciel et des fichiers de documentation associés (le « Logiciel »), de
traiter le Logiciel sans restriction, notamment les droits d'utiliser, copier,
modifier, fusionner, publier, distribuer, sous-licencier et/ou vendre des copies
du Logiciel, et d'autoriser les personnes auxquelles le Logiciel est fourni à
faire de même, sous réserve des conditions suivantes :

La présente notice de droit d'auteur et la présente autorisation doivent être
incluses dans toutes les copies ou parties substantielles du Logiciel.

LE LOGICIEL EST FOURNI « EN L'ÉTAT », SANS GARANTIE D'AUCUNE SORTE, EXPRESSE OU
IMPLICITE, Y COMPRIS, SANS S'Y LIMITER, LES GARANTIES DE QUALITÉ MARCHANDE,
D'ADÉQUATION À UN USAGE PARTICULIER ET D'ABSENCE DE CONTREFAÇON. EN AUCUN CAS
LES AUTEURS OU TITULAIRES DU DROIT D'AUTEUR NE POURRONT ÊTRE TENUS RESPONSABLES
DE TOUTE RÉCLAMATION, DE TOUT DOMMAGE OU DE TOUTE AUTRE RESPONSABILITÉ, QUE CE
SOIT DANS LE CADRE D'UNE ACTION CONTRACTUELLE, DÉLICTUELLE OU AUTRE, DÉCOULANT
DU LOGICIEL OU DE SON UTILISATION, OU EN RELATION AVEC CEUX-CI.
''';

const _bsd3French = '''
Licence BSD à trois clauses — traduction indicative non officielle

La redistribution et l'utilisation sous forme de code source ou binaire, avec
ou sans modification, sont autorisées sous réserve des conditions suivantes :

1. Les redistributions du code source doivent conserver la notice de droit
d'auteur ci-dessus, la présente liste de conditions et l'avertissement qui suit.
2. Les redistributions sous forme binaire doivent reproduire la notice de droit
d'auteur ci-dessus, la présente liste de conditions et l'avertissement dans la
documentation et/ou les autres éléments fournis avec la distribution.
3. Ni le nom du titulaire du droit d'auteur ni ceux de ses contributeurs ne
peuvent être utilisés pour approuver ou promouvoir des produits dérivés de ce
logiciel sans autorisation écrite préalable.

CE LOGICIEL EST FOURNI « EN L'ÉTAT » PAR LE TITULAIRE DU DROIT D'AUTEUR ET SES
CONTRIBUTEURS, QUI DÉCLINENT TOUTE GARANTIE EXPRESSE OU IMPLICITE, Y COMPRIS,
SANS S'Y LIMITER, LES GARANTIES IMPLICITES DE QUALITÉ MARCHANDE ET D'ADÉQUATION
À UN USAGE PARTICULIER. EN AUCUN CAS LE TITULAIRE DU DROIT D'AUTEUR OU SES
CONTRIBUTEURS NE POURRONT ÊTRE TENUS RESPONSABLES DE DOMMAGES DIRECTS,
INDIRECTS, ACCESSOIRES, SPÉCIAUX, EXEMPLAIRES OU CONSÉCUTIFS, NOTAMMENT
L'ACQUISITION DE BIENS OU SERVICES DE REMPLACEMENT, LA PERTE D'UTILISATION, DE
DONNÉES OU DE BÉNÉFICES, OU L'INTERRUPTION D'ACTIVITÉ, QUELLE QU'EN SOIT LA
CAUSE ET QUELLE QUE SOIT LA THÉORIE DE RESPONSABILITÉ INVOQUÉE, CONTRACTUELLE,
STRICTE OU DÉLICTUELLE (Y COMPRIS LA NÉGLIGENCE), DÉCOULANT DE L'UTILISATION DE
CE LOGICIEL, MÊME SI LA POSSIBILITÉ DE TELS DOMMAGES A ÉTÉ SIGNALÉE.
''';

String? _indicativeFrenchLicense(String source) {
  final normalized = source.toLowerCase();
  if (normalized.contains(
    'permission is hereby granted, free of charge, to any person obtaining a copy',
  )) {
    final notices = source
        .split('\n')
        .where((line) => line.trimLeft().toLowerCase().startsWith('copyright'))
        .join('\n');
    return '${notices.isEmpty ? '' : '$notices\n\n'}$_mitThirdPartyFrench';
  }
  if (normalized.contains('redistribution and use in source and binary forms') &&
      (normalized.contains('neither the name') ||
          normalized.contains('endorse or promote'))) {
    return _bsd3French;
  }
  return null;
}

void showKorunLicenses(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr(context, 'legal_information')),
      content: SizedBox(
        width: 520,
        height: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'app_license')),
              if (Localizations.localeOf(context).languageCode != 'en') ...[
                const SizedBox(height: 12),
                Text(
                  licenseTranslationLabel(
                    Localizations.localeOf(context).languageCode,
                    'translation',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SelectableText(
                  Localizations.localeOf(context).languageCode == 'fr'
                      ? _mitLicenseFrench
                      : korunMitTranslation(
                          Localizations.localeOf(context).languageCode,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  licenseTranslationLabel(
                    Localizations.localeOf(context).languageCode,
                    'warning',
                  ),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  licenseTranslationLabel(
                    Localizations.localeOf(context).languageCode,
                    'original',
                  ),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SelectableText(_mitLicenseText),
                  ),
                ],
              ),
              Text(tr(context, 'disclaimer')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr(context, 'cancel')),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ThirdPartyLicensesPage(),
              ),
            );
          },
          child: Text(tr(context, 'third_party_licenses')),
        ),
      ],
    ),
  );
}

class ThirdPartyLicensesPage extends StatelessWidget {
  const ThirdPartyLicensesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(context, 'third_party_licenses'))),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                licenseTranslationLabel(
                  Localizations.localeOf(context).languageCode,
                  'notice',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LicenseEntry>>(
                future: LicenseRegistry.licenses.toList(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: SelectableText(
                        '${tr(context, 'licenses_load_failed')}: '
                        '${snapshot.error}',
                      ),
                    );
                  }
                  final grouped = <String, List<String>>{};
                  for (final entry
                      in snapshot.data ?? const <LicenseEntry>[]) {
                    final text = entry.paragraphs
                        .map((paragraph) => paragraph.text)
                        .join('\n\n');
                    for (final package in entry.packages) {
                      grouped.putIfAbsent(package, () => <String>[]).add(text);
                    }
                  }
                  final packages = grouped.keys.toList()..sort();
                  return ListView.builder(
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final package = packages[index];
                      final licenses = grouped[package]!;
                      return ExpansionTile(
                        title: Text(package),
                        subtitle: Text(
                          '${licenses.length} ${tr(context, 'licenses_count')}',
                        ),
                        children: [
                          for (final license in licenses)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Localizations.localeOf(context)
                                          .languageCode ==
                                      'en'
                                  ? SelectableText(license)
                                  : _LocalizedLicense(text: license),
                            ),
                        ],
                      ),
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _LocalizedLicense extends StatelessWidget {
  const _LocalizedLicense({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final translation = indicativeLicenseTranslation(text, languageCode) ??
        (languageCode == 'fr' ? _indicativeFrenchLicense(text) : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translation == null
              ? licenseTranslationLabel(languageCode, 'unavailable')
              : licenseTranslationLabel(languageCode, 'translation'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (translation != null) ...[
          SelectableText(translation),
          const SizedBox(height: 8),
          Text(licenseTranslationLabel(languageCode, 'warning')),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(licenseTranslationLabel(languageCode, 'original')),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(text),
            ),
          ],
        ),
      ],
    );
  }
}

class KorunAboutDialog extends StatefulWidget {
  const KorunAboutDialog({super.key});
  @override
  State<KorunAboutDialog> createState() => _KorunAboutDialogState();
}

class _KorunAboutDialogState extends State<KorunAboutDialog> {
  bool _autoUpdate = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _autoUpdate = p.getBool('autoUpdate') ?? true));
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final client = HttpClient()..userAgent = 'KorunApp/${AppInfo.version}';
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/${AppInfo.repo}/releases/latest'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final json = jsonDecode(await res.transform(utf8.decoder).join());
        final tag = (json['tag_name'] ?? '').toString().replaceAll('v', '');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tag.isNotEmpty && tag != AppInfo.version
                ? tr(context, 'update_found')
                : 'OK (${AppInfo.version})'),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Image.asset(AppInfo.logoAsset, width: 40, height: 40),
          const SizedBox(width: 12),
          Text(tr(context, 'about')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Körün', style: Theme.of(context).textTheme.titleLarge),
            Text('${tr(context, 'version')} ${AppInfo.version}'),
            Text('${tr(context, 'author')} ${AppInfo.author}'),
            const SizedBox(height: 8),
            Text(tr(context, 'disclaimer'),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            const Divider(),
            SwitchListTile(
              dense: true,
              title: Text(tr(context, 'auto_update')),
              value: _autoUpdate,
              onChanged: (v) async {
                setState(() => _autoUpdate = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('autoUpdate', v);
              },
            ),
            ElevatedButton.icon(
              onPressed: _checking ? null : _checkUpdate,
              icon: _checking
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update_alt, size: 18),
              label: Text(tr(context, 'check_update')),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => showKorunLicenses(context),
              icon: const Icon(Icons.policy_outlined),
              label: Text(tr(context, 'legal_information')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
      ],
    );
  }
}
