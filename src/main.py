#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Körün — Cross-platform dual-pane file manager with timestamps editor & dual trees
Author: David HARPUTOGLU
Version: 0.1.9
License: MIT
"""

import sys
import os
import json
import subprocess
import tempfile
import time
import requests
import datetime
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
    QTreeView, QSplitter, QLabel, QPushButton, QToolBar, QMessageBox,
    QTextEdit, QStackedWidget, QFrame, QHeaderView, QComboBox, QLineEdit,
    QDialog, QFormLayout, QDateTimeEdit, QDialogButtonBox, QMenu
)
from PyQt6.QtCore import Qt, QDir, QSize, QThread, pyqtSignal, QModelIndex, QDateTime
from PyQt6.QtGui import QPixmap, QFileSystemModel, QIcon

try:
    import fitz  # PyMuPDF
    HAS_FITZ = True
except ImportError:
    HAS_FITZ = False

try:
    import docx
    HAS_DOCX = True
except ImportError:
    HAS_DOCX = False

try:
    import openpyxl
    HAS_OPENPYXL = True
except ImportError:
    HAS_OPENPYXL = False

CURRENT_VERSION = "v0.1.9"
GITHUB_REPO = "davidharputoglu/korun"

APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(APP_DIR, "config.json")
ASSETS_DIR = os.path.join(os.path.dirname(APP_DIR), "assets")
ICON_PATH = os.path.join(ASSETS_DIR, "icon.png")

DEFAULT_CONFIG = {
    "language": "FR",
    "theme": "Catppuccin Macchiato",
    "auto_check_updates": True
}

# Modèle personnalisable pour traduire dynamiquement les colonnes dans toutes les langues
class CustomFileSystemModel(QFileSystemModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.lang = "FR"

    def set_language(self, lang):
        self.lang = lang
        self.headerDataChanged.emit(Qt.Orientation.Horizontal, 0, 3)

    def headerData(self, section, orientation, role=Qt.ItemDataRole.DisplayRole):
        if orientation == Qt.Orientation.Horizontal and role == Qt.ItemDataRole.DisplayRole:
            headers = {
                "FR": ["Nom", "Taille", "Type", "Date de modification"],
                "EN": ["Name", "Size", "Type", "Date Modified"],
                "TR": ["Ad", "Boyut", "Tür", "Değiştirilme Tarihi"],
                "AR": ["الاسم", "الحجم", "النوع", "تاريخ التعديل"],
                "AZ": ["Ad", "Ölçü", "Növ", "Dəyişdirilmə Tarixi"],
                "KK": ["Аты", "Өлшемі", "Түрі", "Өзгертілген күні"],
                "UZ": ["Nomi", "Hajmi", "Turi", "O'zgartirilgan sana"],
                "TK": ["Ady", "Ölçegi", "Görnüşi", "Üýtgedilen senesi"],
                "KY": ["Aты", "Өлчөмү", "Түрү", "Өзгөртүлгөн датасы"],
                "IT": ["Nome", "Dimensione", "Tipo", "Data di modifica"],
                "ES": ["Nombre", "Tamaño", "Tipo", "Fecha de modificación"],
                "PT": ["Nome", "Tamanho", "Tipo", "Data de modificação"]
            }
            curr_headers = headers.get(self.lang, headers["FR"])
            if 0 <= section < len(curr_headers):
                return curr_headers[section]
        return super().headerData(section, orientation, role)

TRANSLATIONS = {
    "FR": {
        "title": "Körün — Gestionnaire de fichiers",
        "preview_title": "Aperçu du fichier",
        "preview_empty": "Sélectionnez un fichier pour afficher son aperçu.",
        "toggle_preview": "⇄ Inverser l'aperçu",
        "check_update": "🔄 MAJ",
        "about": "ℹ À propos",
        "up_dir": "⬆ Remonter",
        "edit_dates": "📅 Modifier les dates",
        "created_date": "Date de création :",
        "modified_date": "Date de modification :",
        "accessed_date": "Dernier accès :",
        "dates_success": "Horodatages mis à jour avec succès !",
        "rtl": False
    },
    "EN": {
        "title": "Körün — File Manager",
        "preview_title": "File Preview",
        "preview_empty": "Select a file to preview its content.",
        "toggle_preview": "⇄ Toggle Preview",
        "check_update": "🔄 Update",
        "about": "ℹ About",
        "up_dir": "⬆ Up",
        "edit_dates": "📅 Edit Timestamps",
        "created_date": "Creation Date:",
        "modified_date": "Modification Date:",
        "accessed_date": "Last Access:",
        "dates_success": "Timestamps updated successfully!",
        "rtl": False
    },
    "TR": {
        "title": "Körün — Dosya Yöneticisi",
        "preview_title": "Dosya Önizleme",
        "preview_empty": "Önizlemek için bir dosya seçin.",
        "toggle_preview": "⇄ Önizleme Konumu",
        "check_update": "🔄 Güncelle",
        "about": "ℹ Hakkında",
        "up_dir": "⬆ Yukarı",
        "edit_dates": "📅 Tarihleri Düzenle",
        "created_date": "Oluşturma Tarihi:",
        "modified_date": "Değiştirilme Tarihi:",
        "accessed_date": "Erişim Tarihi:",
        "dates_success": "Zaman damgaları başarıyla güncellendi!",
        "rtl": False
    },
    "AR": {
        "title": "Körün — مدير الملفات",
        "preview_title": "معاينة الملف",
        "preview_empty": "حدد ملفًا لفرض معاينته.",
        "toggle_preview": "⇄ المعاينة",
        "check_update": "🔄 التحديث",
        "about": "ℹ حول",
        "up_dir": "⬆ للأعلى",
        "edit_dates": "📅 تعديل التواريخ",
        "created_date": "تاريخ الإنشاء:",
        "modified_date": "تاريخ التعديل:",
        "accessed_date": "آخر وصول:",
        "dates_success": "تم تحديث الطوابع الزمنية بنجاح!",
        "rtl": True
    }
}

THEME_STYLE = """
QMainWindow { background-color: #1e1e2e; }
QWidget { color: #cdd6f4; font-family: "Segoe UI", "Ubuntu", sans-serif; font-size: 13px; }
QSplitter::handle { background-color: #313244; width: 3px; }
QTreeView { background-color: #181825; border: 1px solid #313244; border-radius: 6px; color: #cdd6f4; outline: none; }
QTreeView::item:hover { background-color: #313244; }
QTreeView::item:selected { background-color: #89b4fa; color: #11111b; font-weight: bold; }
QHeaderView::section { background-color: #181825; color: #a6adc8; border: none; border-bottom: 2px solid #313244; padding: 6px; font-weight: bold; }
QLineEdit { background-color: #181825; border: 1px solid #313244; border-radius: 6px; padding: 6px; color: #89b4fa; font-weight: bold; }
QFrame#PreviewContainer { background-color: #181825; border: 1px solid #313244; border-radius: 6px; padding: 10px; }
QTextEdit#PreviewText { background-color: #ffffff; color: #111111; border: 1px solid #cbd5e1; border-radius: 6px; font-family: "Consolas", monospace; font-size: 13px; padding: 8px; }
QToolBar { background-color: #1e1e2e; border-bottom: 1px solid #313244; spacing: 8px; padding: 6px; }
QPushButton { background-color: #313244; color: #cdd6f4; border: 1px solid #45475a; border-radius: 6px; padding: 6px 12px; font-weight: 600; }
QPushButton:hover { background-color: #89b4fa; color: #11111b; }
QComboBox { background-color: #313244; border: 1px solid #45475a; border-radius: 6px; padding: 4px 8px; color: #cdd6f4; }
"""

class TimestampDialog(QDialog):
    def __init__(self, file_path, lang="FR", parent=None):
        super().__init__(parent)
        self.file_path = file_path
        self.lang = lang
        t = TRANSLATIONS.get(self.lang, TRANSLATIONS["FR"])
        self.setWindowTitle(t["edit_dates"])
        self.setFixedWidth(360)

        layout = QVBoxLayout(self)
        form = QFormLayout()

        stat = os.stat(file_path)

        self.edit_mtime = QDateTimeEdit(QDateTime.fromSecsSinceEpoch(int(stat.st_mtime)))
        self.edit_atime = QDateTimeEdit(QDateTime.fromSecsSinceEpoch(int(stat.st_atime)))
        self.edit_mtime.setCalendarPopup(True)
        self.edit_atime.setCalendarPopup(True)

        form.addRow(t["modified_date"], self.edit_mtime)
        form.addRow(t["accessed_date"], self.edit_atime)

        if sys.platform == "win32":
            self.edit_ctime = QDateTimeEdit(QDateTime.fromSecsSinceEpoch(int(stat.st_ctime)))
            self.edit_ctime.setCalendarPopup(True)
            form.addRow(t["created_date"], self.edit_ctime)

        layout.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.apply_timestamps)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def apply_timestamps(self):
        mtime_ts = self.edit_mtime.dateTime().toSecsSinceEpoch()
        atime_ts = self.edit_atime.dateTime().toSecsSinceEpoch()

        try:
            # Modification date modification & accès
            os.utime(self.file_path, (atime_ts, mtime_ts))

            # Modification date de création sous Windows
            if sys.platform == "win32":
                import ctypes
                from ctypes import wintypes
                ctime_ts = self.edit_ctime.dateTime().toSecsSinceEpoch()
                
                # Conversion du timestamp Unix en FILETIME Windows
                win_time = int((ctime_ts + 11644473600) * 10000000)
                filetime = wintypes.FILETIME(win_time & 0xFFFFFFFF, win_time >> 32)
                
                handle = ctypes.windll.kernel32.CreateFileW(
                    self.file_path, 256, 0, None, 3, 128, None
                )
                if handle != -1:
                    ctypes.windll.kernel32.SetFileTime(handle, ctypes.byref(filetime), None, None)
                    ctypes.windll.kernel32.CloseHandle(handle)

            t = TRANSLATIONS.get(self.lang, TRANSLATIONS["FR"])
            QMessageBox.information(self, "Körün", t["dates_success"])
            self.accept()
        except Exception as e:
            QMessageBox.critical(self, "Erreur", str(e))

class FilePanel(QWidget):
    def __init__(self, lang="FR", parent=None):
        super().__init__(parent)
        self.lang = lang
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(2, 2, 2, 2)

        nav_box = QHBoxLayout()
        self.btn_up = QPushButton("⬆ Remonter")
        self.btn_up.setFixedWidth(100)
        self.btn_up.clicked.connect(self.go_up)
        nav_box.addWidget(self.btn_up)

        self.path_edit = QLineEdit()
        self.path_edit.returnPressed.connect(self.navigate_to_path)
        nav_box.addWidget(self.path_edit)

        self.btn_dates = QPushButton("📅")
        self.btn_dates.setFixedWidth(40)
        self.btn_dates.clicked.connect(self.open_timestamp_dialog)
        nav_box.addWidget(self.btn_dates)

        self.layout.addLayout(nav_box)

        # Modèle & Arborescence latérale dédiée
        self.model = CustomFileSystemModel()
        self.model.setRootPath(QDir.rootPath())

        self.panel_splitter = QSplitter(Qt.Orientation.Horizontal)

        self.side_tree = QTreeView()
        self.side_tree.setModel(self.model)
        self.side_tree.setHeaderHidden(True)
        self.side_tree.setColumnHidden(1, True)
        self.side_tree.setColumnHidden(2, True)
        self.side_tree.setColumnHidden(3, True)

        self.tree = QTreeView()
        self.tree.setModel(self.model)
        
        home_path = QDir.homePath()
        self.tree.setRootIndex(self.model.index(home_path))
        self.side_tree.setRootIndex(self.model.index(home_path))
        self.path_edit.setText(home_path)

        self.tree.setAnimated(True)
        self.tree.setIndentation(16)
        self.tree.setSortingEnabled(True)
        self.tree.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)

        self.panel_splitter.addWidget(self.side_tree)
        self.panel_splitter.addWidget(self.tree)
        self.panel_splitter.setSizes([160, 450])

        self.layout.addWidget(self.panel_splitter)

        self.tree.doubleClicked.connect(self.on_double_click)
        self.side_tree.doubleClicked.connect(self.on_side_tree_click)
        self.tree.selectionModel().selectionChanged.connect(self.update_path_display)

    def on_double_click(self, index: QModelIndex):
        if self.model.isDir(index):
            self.tree.setRootIndex(index)
            self.path_edit.setText(self.model.filePath(index))

    def on_side_tree_click(self, index: QModelIndex):
        if self.model.isDir(index):
            self.tree.setRootIndex(index)
            self.path_edit.setText(self.model.filePath(index))

    def go_up(self):
        current_root = self.tree.rootIndex()
        parent_root = current_root.parent()
        if parent_root.isValid():
            self.tree.setRootIndex(parent_root)
            self.path_edit.setText(self.model.filePath(parent_root))

    def navigate_to_path(self):
        target_path = self.path_edit.text()
        if os.path.exists(target_path) and os.path.isdir(target_path):
            index = self.model.index(target_path)
            if index.isValid():
                self.tree.setRootIndex(index)

    def update_path_display(self):
        path = self.get_selected_path()
        if path and not os.path.isdir(path):
            self.path_edit.setText(path)

    def get_selected_path(self):
        index = self.tree.currentIndex()
        if index.isValid():
            return self.model.filePath(index)
        return None

    def open_timestamp_dialog(self):
        path = self.get_selected_path()
        if path and os.path.exists(path):
            dialog = TimestampDialog(path, lang=self.lang, parent=self)
            dialog.exec()

class PreviewWidget(QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("PreviewContainer")
        self.layout = QVBoxLayout(self)

        self.title_label = QLabel("Aperçu du fichier")
        self.title_label.setObjectName("PreviewTitle")
        self.title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.layout.addWidget(self.title_label)

        self.stack = QStackedWidget()

        self.lbl_empty = QLabel()
        self.lbl_empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_empty.setWordWrap(True)
        self.stack.addWidget(self.lbl_empty)

        self.lbl_image = QLabel()
        self.lbl_image.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.stack.addWidget(self.lbl_image)

        self.txt_preview = QTextEdit()
        self.txt_preview.setObjectName("PreviewText")
        self.txt_preview.setReadOnly(True)
        self.stack.addWidget(self.txt_preview)

        self.layout.addWidget(self.stack)

    def preview_file(self, file_path):
        if not file_path or not os.path.isfile(file_path):
            self.stack.setCurrentIndex(0)
            return

        ext = os.path.splitext(file_path)[1].lower()

        if ext in ['.doc', '.xls', '.ppt', '.rtf']:
            try:
                temp_dir = tempfile.gettempdir()
                cmd = ['libreoffice', '--headless', '--convert-to', 'html', '--outdir', temp_dir, file_path]
                subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)

                base_name = os.path.splitext(os.path.basename(file_path))[0]
                html_path = os.path.join(temp_dir, f"{base_name}.html")

                if os.path.exists(html_path):
                    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
                        html_content = f.read()
                    self.txt_preview.setHtml(html_content)
                    self.stack.setCurrentIndex(2)
                    return
            except Exception:
                pass

        if ext in ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.svg']:
            pixmap = QPixmap(file_path)
            if not pixmap.isNull():
                scaled = pixmap.scaled(420, 420, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                self.lbl_image.setPixmap(scaled)
                self.stack.setCurrentIndex(1)
                return

        if ext == '.pdf' and HAS_FITZ:
            try:
                doc = fitz.open(file_path)
                page = doc.load_page(0)
                pix = page.get_pixmap(dpi=150)
                pixmap = QPixmap()
                pixmap.loadFromData(pix.tobytes())
                scaled = pixmap.scaled(420, 550, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                self.lbl_image.setPixmap(scaled)
                self.stack.setCurrentIndex(1)
                return
            except Exception:
                pass

        if ext in ['.txt', '.md', '.py', '.json', '.xml', '.html', '.css', '.js', '.sh', '.ini', '.conf']:
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read(8000)
                self.txt_preview.setPlainText(content)
                self.stack.setCurrentIndex(2)
                return
            except Exception:
                pass

        self.lbl_empty.setText(f"<b>{os.path.basename(file_path)}</b>")
        self.stack.setCurrentIndex(0)

class KorunApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.current_lang = "FR"
        self.setStyleSheet(THEME_STYLE)
        self.resize(1400, 850)

        if os.path.exists(ICON_PATH):
            self.setWindowIcon(QIcon(ICON_PATH))

        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)

        self.panel_left = FilePanel(lang=self.current_lang)
        self.panel_right = FilePanel(lang=self.current_lang)

        self.panels_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.panels_splitter.addWidget(self.panel_left)
        self.panels_splitter.addWidget(self.panel_right)

        self.preview = PreviewWidget()

        self.main_splitter.addWidget(self.panels_splitter)
        self.main_splitter.addWidget(self.preview)
        self.main_splitter.setSizes([950, 420])

        self.setCentralWidget(self.main_splitter)

        self.panel_left.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_left.get_selected_path())
        )
        self.panel_right.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_right.get_selected_path())
        )

        self.create_toolbar()
        self.retranslate_ui()

    def create_toolbar(self):
        self.toolbar = QToolBar("Barre principale")
        self.addToolBar(self.toolbar)

        self.btn_toggle_preview = QPushButton("⇄ Aperçu")
        self.btn_toggle_preview.clicked.connect(self.toggle_preview_position)
        self.toolbar.addWidget(self.btn_toggle_preview)

        self.toolbar.addSeparator()

        self.lbl_lang = QLabel("Langue :")
        self.toolbar.addWidget(self.lbl_lang)

        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["FR", "EN", "TR", "AR", "AZ", "KK", "UZ", "TK", "KY", "IT", "ES", "PT"])
        self.combo_lang.currentTextChanged.connect(self.change_language)
        self.toolbar.addWidget(self.combo_lang)

        self.toolbar.addSeparator()

        self.btn_about = QPushButton("ℹ À propos")
        self.btn_about.clicked.connect(self.show_about)
        self.toolbar.addWidget(self.btn_about)

    def change_language(self, lang_code):
        self.current_lang = lang_code
        self.panel_left.lang = lang_code
        self.panel_right.lang = lang_code
        self.retranslate_ui()

    def retranslate_ui(self):
        t = TRANSLATIONS.get(self.current_lang, TRANSLATIONS["FR"])
        self.setWindowTitle(f"{t['title']} — {CURRENT_VERSION}")
        self.panel_left.model.set_language(self.current_lang)
        self.panel_right.model.set_language(self.current_lang)
        self.panel_left.btn_up.setText(t["up_dir"])
        self.panel_right.btn_up.setText(t["up_dir"])

        if t.get("rtl", False):
            self.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        else:
            self.setLayoutDirection(Qt.LayoutDirection.LeftToRight)

    def toggle_preview_position(self):
        if self.main_splitter.indexOf(self.preview) == 1:
            self.main_splitter.insertWidget(0, self.preview)
        else:
            self.main_splitter.addWidget(self.preview)

    def show_about(self):
        QMessageBox.about(
            self,
            "Körün",
            f"<h3>Körün — {CURRENT_VERSION}</h3>"
            "<p>Gestionnaire de fichiers multiplateforme à double panneau et double arborescence.</p>"
            "<hr><p><b>Auteur :</b> David HARPUTOGLU<br><b>Contact :</b> kasparof57@gmail.com<br><b>Licence :</b> MIT</p>"
        )

def main():
    app = QApplication(sys.argv)
    if os.path.exists(ICON_PATH):
        app.setWindowIcon(QIcon(ICON_PATH))
    window = KorunApp()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
