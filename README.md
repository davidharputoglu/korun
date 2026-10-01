# Körün

**[Français](#français) · [English](#english) · [Türkçe](#türkçe)**

## Français

Körün est un gestionnaire de fichiers à deux panneaux pour Linux et Windows,
avec des aperçus de fichiers indépendants dans chaque panneau.

### Fonctionnalités
- Aperçus d’images, SVG, PDF, texte et code, vidéos et pochettes audio,
  contenu des archives, documents Office et vue hexadécimale des fichiers
  binaires.
- Menu contextuel avec ouverture, « Ouvrir avec… » sous Linux et Windows, copier,
  couper, coller, renommer, suppression, propriétés, compression ZIP et
  extraction sécurisée des archives ZIP.
- Thèmes clair, sombre et noir OLED, couleurs d’accent prédéfinies et thèmes
  personnalisés ; 12 langues, dont le français, l’anglais et le turc.
- Affichage des fichiers cachés, vues liste/grille, tri, raccourcis clavier,
  édition des dates, recherche rapide indexée (`Ctrl+F`) dans les disques
  accessibles et historique Ötken des snapshots.
- Filtres de recherche combinables : nom, chemin, extension, catégorie de
  fichier, taille et date de modification; recherche `content:` dans les
  fichiers texte jusqu’à 1 Mio. Les emplacements réseau non montés peuvent
  être ajoutés depuis la fenêtre de recherche.
- Page d’informations légales intégrée : elle affiche les licences des
  dépendances Flutter.

### Aperçus et dépendances facultatives
- `ffmpeg` est nécessaire pour générer les miniatures vidéo et les pochettes
  audio. Sans lui, Körün affiche l’icône du type de média et explique que
  l’aperçu n’est pas disponible ; le contenu binaire n’est pas présenté comme
  du texte.
- LibreOffice (`soffice`) est nécessaire pour convertir les documents Office
  en PDF afin de les prévisualiser.
- Ces outils ne sont pas inclus dans les paquets publiés.

### Informations légales
Körün est distribué sous licence **MIT** ; consultez le fichier [`LICENSE`](LICENSE).
Les licences des dépendances tierces sont consultables dans l’application via
**Paramètres → Licences et informations légales**. Le logiciel est fourni tel
quel, sans garantie.

### Limitations
- Sous Linux, la date de création ne peut pas être modifiée avec les API
  disponibles du noyau. Körün l’affiche si elle est fournie par le système ;
  la date de création est modifiable sous Windows. Les dates de modification
  et d’accès sont modifiables sur les deux systèmes.
- Ötken dépend de la présence et de la configuration de snapshots sur le
  système (Btrfs ou Timeshift).
- La première indexation de la recherche peut prendre du temps sur les gros
  disques ou les partages réseau. Les recherches suivantes interrogent l’index
  local; seuls les emplacements accessibles et indexés sont inclus. Réindexez
  après avoir ajouté un disque ou modifié un partage.

### Téléchargements et publication
La [page des releases](https://github.com/davidharputoglu/korun/releases)
contient les paquets Linux x64 (`.deb`, `.rpm`, AppImage et archive `.tar.gz`)
et Windows x64 (installateur `.exe` et archive portable `.zip`). Les versions
sont construites par GitHub Actions quand un tag `v*` est poussé. Le numéro
de version de l’application se trouve dans `pubspec.yaml`.

### Compilation
Installez Flutter, puis lancez :

```sh
flutter pub get
flutter run
```

Pour construire la version de production de votre plateforme :

```sh
flutter build linux --release
flutter build windows --release
```

Les deux dernières commandes dépendent de la plateforme et de ses outils de
compilation.

## English

Körün is a dual-pane file manager for Linux and Windows, with an independent
file preview alongside each pane.

### Features
- Previews for images, SVG, PDF, text and code, video thumbnails and audio
  covers, archive contents, Office documents, and hexadecimal views of binary
  files.
- Context menu actions for opening, **Open with…** on Linux and Windows, copy, cut,
  paste, rename, delete, properties, ZIP compression, and safe ZIP extraction.
- Light, dark, and OLED-black themes; preset accent colors and custom themes;
  12 languages, including French, English, and Turkish.
- Hidden files, list/grid views, sorting, keyboard shortcuts, date editing,
  and Ötken snapshot history.
- Built-in legal information page listing Flutter dependency licenses.

### Previews and optional dependencies
- `ffmpeg` is required to generate video thumbnails and audio covers. Without
  it, Körün displays the media-type icon and explains that the preview is
  unavailable instead of displaying binary data as text.
- LibreOffice (`soffice`) is required to convert Office documents to PDF for
  preview.
- These tools are not bundled with the release packages.

### Legal information
Körün is distributed under the **MIT License**; see [`LICENSE`](LICENSE).
Licenses for third-party dependencies are available in the app under
**Settings → Licenses and legal information**. The software is provided as
is, without warranty.

### Limitations
- Linux does not expose a supported kernel API for changing a file’s creation
  time. Körün displays it when the system provides it; creation time can be
  changed on Windows. Modified and accessed times can be changed on both
  platforms.
- Ötken requires snapshots to be present and configured on the system
  (Btrfs or Timeshift).

### Downloads and releases
The [GitHub Releases page](https://github.com/davidharputoglu/korun/releases)
provides Linux x64 packages (`.deb`, `.rpm`, AppImage, and portable `.tar.gz`)
and Windows x64 packages (installer `.exe` and portable `.zip`). GitHub
Actions builds and publishes packages when a `v*` tag is pushed. The
application version is defined in `pubspec.yaml`.

### Build
Install Flutter, then run:

```sh
flutter pub get
flutter run
```

To build a production version for your platform:

```sh
flutter build linux --release
flutter build windows --release
```

Each build command requires its respective platform and build tools.

## Türkçe

Körün, Linux ve Windows için her panelin yanında bağımsız dosya önizlemesi
sunan çift panelli bir dosya yöneticisidir.

### Özellikler
- Resim, SVG, PDF, metin ve kod önizlemeleri; video küçük resimleri ve ses
  kapakları; arşiv içerikleri; Office belgeleri ve ikili dosyalar için onaltılık
  görünüm.
- Açma, Linux ve Windows’ta **Birlikte aç…**, kopyalama, kesme, yapıştırma, yeniden
  adlandırma, silme, özellikler, ZIP sıkıştırma ve güvenli ZIP çıkarma için
  bağlam menüsü.
- Açık, koyu ve OLED siyah temalar; hazır vurgu renkleri ve özel temalar;
  Fransızca, İngilizce ve Türkçe dâhil 12 dil.
- Gizli dosyalar, liste/ızgara görünümleri, sıralama, klavye kısayolları, tarih
  düzenleme ve Ötken snapshot geçmişi.
- Flutter bağımlılıklarının lisanslarını listeleyen yerleşik yasal bilgiler
  sayfası.

### Önizlemeler ve isteğe bağlı bağımlılıklar
- Video küçük resimleri ve ses kapakları oluşturmak için `ffmpeg` gerekir.
  Kurulu değilse Körün, ikili veriyi metin gibi göstermek yerine medya türü
  simgesini ve önizlemenin kullanılamadığı bilgisini gösterir.
- Office belgelerini önizleme için PDF’ye dönüştürmek üzere LibreOffice
  (`soffice`) gerekir.
- Bu araçlar yayımlanan paketlere dâhil değildir.

### Yasal bilgiler
Körün **MIT Lisansı** ile dağıtılır; tam metin için [`LICENSE`](LICENSE)
dosyasına bakın. Üçüncü taraf bağımlılıkların lisanslarına uygulamada
**Ayarlar → Lisanslar ve yasal bilgiler** bölümünden ulaşabilirsiniz. Yazılım
olduğu gibi sunulur ve herhangi bir garanti verilmez.

### Sınırlamalar
- Linux, dosya oluşturma zamanını değiştirmek için desteklenen bir çekirdek
  API’si sunmaz. Körün sistem tarafından sağlanıyorsa bu zamanı gösterir;
  oluşturma zamanı Windows’ta değiştirilebilir. Değiştirilme ve erişim
  zamanları her iki platformda da değiştirilebilir.
- Ötken’in çalışması için sistemde snapshot bulunmalı ve yapılandırılmış
  olmalıdır (Btrfs veya Timeshift).

### İndirmeler ve sürümler
[GitHub Releases sayfasında](https://github.com/davidharputoglu/korun/releases)
Linux x64 paketleri (`.deb`, `.rpm`, AppImage ve taşınabilir `.tar.gz`) ile
Windows x64 paketleri (kurulum `.exe` dosyası ve taşınabilir `.zip`) bulunur.
Bir `v*` etiketi gönderildiğinde GitHub Actions paketleri oluşturup yayımlar.
Uygulama sürümü `pubspec.yaml` dosyasında tanımlıdır.

### Derleme
Flutter’ı yükledikten sonra şu komutları çalıştırın:

```sh
flutter pub get
flutter run
```

Platformunuz için üretim derlemesi almak üzere:

```sh
flutter build linux --release
flutter build windows --release
```

Her derleme komutu ilgili platformu ve derleme araçlarını gerektirir.
