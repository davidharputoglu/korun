# Körün

Gestionnaire de fichiers double panneau à aperçus réels, pour Linux et Windows.

## Fonctionnalités
- Double panneau (gauche / droite) + volet d'aperçu réel : images, SVG,
  PDF (rendu pdfium), texte/code avec numéros de lignes, vidéos (miniature
  ffmpeg), audio (pochette ffmpeg), archives (liste réelle du contenu),
  documents Office (conversion LibreOffice), vue hexadécimale des binaires.
- Thèmes : Clair / Sombre / Noir OLED + accents (Turquoise par défaut,
  Bleu, Émeraude, Pourpre, Ambre, Or, Crimson) + thèmes personnalisés
  enregistrables.
- 12 langues : FR, EN, PT, ES, AR (RTL), TR, AZ, UZ, KK, TK, KY, TT.
- Fichiers cachés (bouton, Ctrl+H et option persistante), icônes typées,
  raccourcis Tab / Ctrl+H.
- Éditeur de dates (modification, accès ; création sous Windows).
- Ötken : historique de versions / snapshots (Btrfs /.snapshots, Timeshift).
- Mise à jour silencieuse via l'API GitHub.

## Dépendances système optionnelles
- `ffmpeg` : miniatures vidéo et pochettes audio.
- `libreoffice` (`soffice`) : aperçu des documents Office.

## Limitations connues (transparence)
- **Date de création sous Linux** : le noyau Linux n'expose aucune API
  permettant de modifier la date de création (btime/crtime) d'un fichier
  (ext4, btrfs, xfs). Körün l'affiche donc en **lecture seule** sous Linux,
  avec la vraie date de naissance lue via `stat`. Elle reste **modifiable
  sous Windows** (Win32 `SetFileTime`). Les dates de modification et
  d'accès sont modifiables sur les deux systèmes.
- Les aperçus vidéo/audio nécessitent `ffmpeg` ; sans lui, Körün affiche
  l'icône typée et les métadonnées.

## Règle de versionnage
Le mainteneur annonce la version de base (ex. 0.6) ; les correctifs sont
numérotés 0.6.1, 0.6.2, … Le workflow GitHub Actions lit `pubspec.yaml`
pour nommer automatiquement chaque release.

## Compilation
