# Körün

**[English](#english) · [Français](#français) · [Türkçe](#türkçe)**

## English

Körün is a dual-pane file manager for Linux and Windows, with independent file
previews alongside each pane.

### Features
- Previews for images, SVG, PDF, text and code, video thumbnails and audio
  covers, archive contents, Office documents, and hexadecimal views of binary
  files.
- Context-menu actions for opening, **Open with…** on Linux and Windows, copy,
  cut, paste, rename, delete, properties, and creation of ZIP, TAR, TAR.GZ,
  TAR.BZ2, TAR.XZ, and standalone GZIP/BZIP2/XZ files. If 7-Zip or WinRAR/RAR
  is installed, it can also create 7z or RAR archives. Körün offers a choice
  between its built-in encoder and each detected external archiver.
- Safe extraction of ZIP/CBZ and TAR variants, standalone GZIP/BZIP2/XZ
  decompression, and extraction of 7z/RAR using compatible installed tools.
- Light, dark, and OLED-black themes; preset accent colors and custom themes;
  12 languages, including English, French, and Turkish.
- Hidden files, list/grid views, sorting, keyboard shortcuts, date editing,
  indexed quick search (`Ctrl+F`) across accessible drives, and Ötken snapshot
  history.
- Search filters can be combined: name, path, extension, file category, size,
  and modified date. `content:` searches text files up to 1 MiB. Unmounted
  network locations can be added from the search window.
- Built-in legal information page listing Flutter dependency licenses.
- Archive previews list entries and show a limited set of contained images for
  built-in ZIP/CBZ and TAR variants. 7z/RAR previews are not built in.

### Previews and optional dependencies
- `ffmpeg` is required to generate video thumbnails and audio covers. Without
  it, Körün displays the media-type icon and explains that the preview is
  unavailable instead of displaying binary data as text.
- LibreOffice (`soffice`) is required to convert Office documents to PDF for
  preview.
- 7-Zip or WinRAR/RAR is optional for 7z/RAR operations; Körün detects
  compatible command-line tools and offers them as a compression method.
- These tools are not bundled with the release packages.

### Legal information
Körün is distributed under the **MIT License**; see [`LICENSE`](LICENSE).
Licenses for third-party dependencies are available in the app under
**Settings → Licenses and legal information**. The software is provided as is,
without warranty.

### Limitations
- Linux does not expose a supported kernel API for changing a file’s creation
  time. Körün displays it when the system provides it; creation time can be
  changed on Windows. Modified and accessed times can be changed on both
  platforms.
- Ötken requires snapshots to be present and configured on the system
  (Btrfs or Timeshift).
- The first search index can take time to build on large drives or network
  shares. Later searches query the local index and include only accessible,
  indexed locations. Reindex after adding a drive or changing a share.

### Downloads and releases
The [GitHub Releases page](https://github.com/davidharputoglu/korun/releases)
provides Linux x64 packages (`.deb`, `.rpm`, AppImage, and portable `.tar.gz`)
and Windows x64 packages (installer `.exe` and portable `.zip`). GitHub Actions
builds and publishes packages when a `v*` tag is pushed. The application
version is defined in `pubspec.yaml`.

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

## Français

Körün est un gestionnaire de fichiers à deux panneaux pour Linux et Windows,
avec des aperçus indépendants à côté de chaque panneau.

### Fonctionnalités
- Aperçus d’images, SVG, PDF, texte et code, miniatures vidéo et pochettes
  audio, contenu des archives, documents Office et vue hexadécimale des fichiers
  binaires.
- Menu contextuel pour ouvrir, **Ouvrir avec…** sous Linux et Windows, copier,
  couper, coller, renommer, supprimer, afficher les propriétés et créer des
  archives ZIP, TAR, TAR.GZ, TAR.BZ2, TAR.XZ et des fichiers GZIP/BZIP2/XZ
  autonomes. Si 7-Zip ou WinRAR/RAR est installé, Körün peut aussi créer des
  archives 7z ou RAR et propose le choix entre Körün et les outils détectés.
- Extraction sécurisée de ZIP/CBZ et des variantes TAR, décompression GZIP,
  BZIP2 et XZ autonomes, et extraction 7z/RAR avec un outil compatible installé.
- Thèmes clair, sombre et noir OLED, couleurs d’accent prédéfinies et thèmes
  personnalisés ; 12 langues, dont l’anglais, le français et le turc.
- Fichiers cachés, vues liste/grille, tri, raccourcis clavier, édition des
  dates, recherche rapide indexée (`Ctrl+F`) dans les disques accessibles et
  historique Ötken des snapshots.
- Filtres combinables : nom, chemin, extension, catégorie, taille et date de
  modification. `content:` recherche dans les fichiers texte jusqu’à 1 Mio.
  Les emplacements réseau non montés peuvent être ajoutés depuis la recherche.
- Page d’informations légales intégrée listant les licences des dépendances
  Flutter.
- Les aperçus d’archives listent les entrées et montrent un nombre limité
  d’images contenues dans les formats intégrés ZIP/CBZ et TAR. Les aperçus 7z
  et RAR ne sont pas intégrés.

### Aperçus et dépendances facultatives
- `ffmpeg` est nécessaire pour générer les miniatures vidéo et les pochettes
  audio. Sans lui, Körün affiche l’icône du type de média et explique que
  l’aperçu n’est pas disponible ; les données binaires ne sont pas présentées
  comme du texte.
- LibreOffice (`soffice`) est nécessaire pour convertir les documents Office
  en PDF afin de les prévisualiser.
- 7-Zip ou WinRAR/RAR est facultatif pour les opérations 7z/RAR ; Körün détecte
  les outils en ligne de commande compatibles et les propose comme méthode de
  compression.
- Ces outils ne sont pas inclus dans les paquets publiés.

### Informations légales
Körün est distribué sous licence **MIT** ; consultez le fichier
[`LICENSE`](LICENSE). Les licences des dépendances tierces sont consultables
dans l’application via **Paramètres → Licences et informations légales**. Le
logiciel est fourni tel quel, sans garantie.

### Limitations
- Sous Linux, aucune API de noyau prise en charge ne permet de modifier la date
  de création. Körün l’affiche si le système la fournit ; elle peut être
  modifiée sous Windows. Les dates de modification et d’accès sont modifiables
  sur les deux systèmes.
- Ötken nécessite la présence et la configuration de snapshots sur le système
  (Btrfs ou Timeshift).
- La première indexation peut prendre du temps sur les gros disques ou les
  partages réseau. Les recherches suivantes interrogent l’index local et
  incluent uniquement les emplacements accessibles et indexés. Réindexez après
  l’ajout d’un disque ou la modification d’un partage.

### Téléchargements et publications
La [page des releases GitHub](https://github.com/davidharputoglu/korun/releases)
contient les paquets Linux x64 (`.deb`, `.rpm`, AppImage et archive portable
`.tar.gz`) ainsi que les paquets Windows x64 (installateur `.exe` et archive
portable `.zip`). GitHub Actions construit et publie les paquets lorsqu’un tag
`v*` est poussé. La version de l’application est définie dans `pubspec.yaml`.

### Compilation
Installez Flutter, puis lancez :

```sh
flutter pub get
flutter run
```

Pour construire une version de production pour votre plateforme :

```sh
flutter build linux --release
flutter build windows --release
```

Chaque commande nécessite la plateforme et les outils de compilation
correspondants.

## Türkçe

Körün, Linux ve Windows için her panelin yanında bağımsız dosya önizlemesi
sunan çift panelli bir dosya yöneticisidir.

### Özellikler
- Resim, SVG, PDF, metin ve kod önizlemeleri; video küçük resimleri ve ses
  kapakları; arşiv içerikleri; Office belgeleri ve ikili dosyalar için
  onaltılık görünüm.
- Açma, Linux ve Windows’ta **Birlikte aç…**, kopyalama, kesme, yapıştırma,
  yeniden adlandırma, silme, özellikleri görüntüleme ve ZIP, TAR, TAR.GZ,
  TAR.BZ2, TAR.XZ arşivleri ile bağımsız GZIP/BZIP2/XZ dosyaları oluşturma.
  7-Zip veya WinRAR/RAR kuruluysa 7z ya da RAR arşivleri de oluşturulabilir ve
  Körün ile algılanan araçlar arasında seçim sunulur.
- ZIP/CBZ ve TAR çeşitlerini güvenli çıkarma, bağımsız GZIP/BZIP2/XZ dosyalarını
  açma ve uyumlu araçlar kuruluysa 7z/RAR arşivlerini çıkarma.
- Açık, koyu ve OLED siyah temalar; hazır vurgu renkleri ve özel temalar;
  İngilizce, Fransızca ve Türkçe dâhil 12 dil.
- Gizli dosyalar, liste/ızgara görünümleri, sıralama, klavye kısayolları, tarih
  düzenleme, erişilebilir sürücülerde dizinli hızlı arama (`Ctrl+F`) ve Ötken
  snapshot geçmişi.
- Birleştirilebilir arama filtreleri: ad, yol, uzantı, dosya kategorisi, boyut
  ve değiştirilme tarihi. `content:` en fazla 1 MiB boyutundaki metin
  dosyalarında arama yapar. Bağlı olmayan ağ konumları arama penceresinden
  eklenebilir.
- Flutter bağımlılıklarının lisanslarını listeleyen yerleşik yasal bilgiler
  sayfası.
- Arşiv önizlemesi, desteklenen ZIP/CBZ ve TAR çeşitlerinin içerik listesini ve
  sınırlı sayıda görselini gösterir. 7z/RAR önizlemesi yerleşik değildir.

### Önizlemeler ve isteğe bağlı bağımlılıklar
- Video küçük resimleri ve ses kapakları oluşturmak için `ffmpeg` gerekir.
  Kurulu değilse Körün, ikili veriyi metin gibi göstermek yerine medya türü
  simgesini ve önizlemenin kullanılamadığı bilgisini gösterir.
- Office belgelerini önizleme için PDF’ye dönüştürmek üzere LibreOffice
  (`soffice`) gerekir.
- 7z/RAR işlemleri için 7-Zip veya WinRAR/RAR isteğe bağlıdır; Körün uyumlu
  komut satırı araçlarını algılar ve sıkıştırma yöntemi olarak sunar.
- Bu araçlar yayımlanan paketlere dâhil değildir.

### Yasal bilgiler
Körün **MIT Lisansı** ile dağıtılır; tam metin için [`LICENSE`](LICENSE)
dosyasına bakın. Üçüncü taraf bağımlılıkların lisanslarına uygulamada
**Ayarlar → Lisanslar ve yasal bilgiler** bölümünden ulaşabilirsiniz. Yazılım
olduğu gibi sunulur ve herhangi bir garanti verilmez.

### Sınırlamalar
- Linux’ta dosya oluşturma zamanını değiştirmek için desteklenen bir çekirdek
  API’si yoktur. Körün, sistem sağlıyorsa bu zamanı gösterir; oluşturma zamanı
  Windows’ta değiştirilebilir. Değiştirilme ve erişim zamanları her iki
  platformda da değiştirilebilir.
- Ötken’in çalışması için sistemde snapshot bulunmalı ve yapılandırılmış
  olmalıdır (Btrfs veya Timeshift).
- Büyük sürücülerde veya ağ paylaşımlarında ilk arama dizininin oluşturulması
  zaman alabilir. Sonraki aramalar yerel dizini kullanır ve yalnızca erişilebilir,
  dizine eklenmiş konumları kapsar. Sürücü ekledikten veya paylaşım
  değiştirdikten sonra dizini yenileyin.

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

Her komut ilgili platformu ve derleme araçlarını gerektirir.
