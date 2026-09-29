#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Körün — Portable dual-pane file manager with sidebar tree and theme manager
Author: David HARPUTOGLU
Version: 0.1.6
License: MIT
"""

import sys
import os
import json
import subprocess
import tempfile
import requests
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
    QTreeView, QSplitter, QLabel, QPushButton, QToolBar, QMessageBox,
    QTextEdit, QStackedWidget, QFrame, QHeaderView, QComboBox, QLineEdit,
    QDialog, QFormLayout, QCheckBox, QDialogButtonBox
)
from PyQt6.QtCore import Qt, QDir, QSize, QThread, pyqtSignal, QModelIndex
from PyQt6.QtGui import QPixmap, QFileSystemModel

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

CURRENT_VERSION = "v0.1.7"
GITHUB_REPO = "davidharputoglu/korun"

# Configuration portable locale
APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(APP_DIR, "config.json")

DEFAULT_CONFIG = {
    "language": "FR",
    "theme": "Catppuccin Macchiato",
    "show_tree": True,
    "auto_check_updates": True
}

THEMES = {
    "Catppuccin Macchiato": """
        QMainWindow, QDialog { background-color: #1e1e2e; }
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
    """,
    "Nord": """
        QMainWindow, QDialog { background-color: #2e3440; }
        QWidget { color: #eceff4; font-family: "Segoe UI", sans-serif; font-size: 13px; }
        QSplitter::handle { background-color: #4c566a; width: 3px; }
        QTreeView { background-color: #3b4252; border: 1px solid #4c566a; border-radius: 6px; color: #eceff4; }
        QTreeView::item:hover { background-color: #434c5e; }
        QTreeView::item:selected { background-color: #88c0d0; color: #2e3440; font-weight: bold; }
        QHeaderView::section { background-color: #3b4252; color: #d8dee9; border: none; border-bottom: 2px solid #4c566a; padding: 6px; }
        QLineEdit { background-color: #3b4252; border: 1px solid #4c566a; border-radius: 6px; padding: 6px; color: #88c0d0; font-weight: bold; }
        QFrame#PreviewContainer { background-color: #3b4252; border: 1px solid #4c566a; border-radius: 6px; padding: 10px; }
        QTextEdit#PreviewText { background-color: #ffffff; color: #2e3440; border: 1px solid #d8dee9; border-radius: 6px; font-family: "Consolas", monospace; font-size: 13px; }
        QToolBar { background-color: #2e3440; border-bottom: 1px solid #4c566a; spacing: 8px; padding: 6px; }
        QPushButton { background-color: #434c5e; color: #eceff4; border: 1px solid #4c566a; border-radius: 6px; padding: 6px 12px; }
        QPushButton:hover { background-color: #88c0d0; color: #2e3440; }
        QComboBox { background-color: #434c5e; border: 1px solid #4c566a; border-radius: 6px; padding: 4px 8px; color: #eceff4; }
    """,
    "VS Code Dark": """
        QMainWindow, QDialog { background-color: #1e1e1e; }
        QWidget { color: #cccccc; font-family: "Segoe UI", sans-serif; font-size: 13px; }
        QSplitter::handle { background-color: #2d2d2d; width: 3px; }
        QTreeView { background-color: #252526; border: 1px solid #3c3c3c; border-radius: 4px; color: #cccccc; }
        QTreeView::item:hover { background-color: #2a2d2e; }
        QTreeView::item:selected { background-color: #094771; color: #ffffff; font-weight: bold; }
        QHeaderView::section { background-color: #252526; color: #858585; border: none; border-bottom: 2px solid #3c3c3c; padding: 6px; }
        QLineEdit { background-color: #3c3c3c; border: 1px solid #555555; border-radius: 4px; padding: 6px; color: #9cdcfe; font-weight: bold; }
        QFrame#PreviewContainer { background-color: #252526; border: 1px solid #3c3c3c; border-radius: 4px; padding: 10px; }
        QTextEdit#PreviewText { background-color: #ffffff; color: #000000; border: 1px solid #cccccc; border-radius: 4px; font-family: "Consolas", monospace; font-size: 13px; }
        QToolBar { background-color: #1e1e1e; border-bottom: 1px solid #2d2d2d; spacing: 8px; padding: 6px; }
        QPushButton { background-color: #3c3c3c; color: #cccccc; border: 1px solid #555555; border-radius: 4px; padding: 6px 12px; }
        QPushButton:hover { background-color: #0e639c; color: #ffffff; }
        QComboBox { background-color: #3c3c3c; border: 1px solid #555555; border-radius: 4px; padding: 4px 8px; color: #cccccc; }
    """,
    "Clair Épuré": """
        QMainWindow, QDialog { background-color: #f8fafc; }
        QWidget { color: #0f172a; font-family: "Segoe UI", sans-serif; font-size: 13px; }
        QSplitter::handle { background-color: #e2e8f0; width: 3px; }
        QTreeView { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; color: #0f172a; }
        QTreeView::item:hover { background-color: #f1f5f9; }
        QTreeView::item:selected { background-color: #2563eb; color: #ffffff; font-weight: bold; }
        QHeaderView::section { background-color: #f1f5f9; color: #475569; border: none; border-bottom: 2px solid #cbd5e1; padding: 6px; }
        QLineEdit { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 6px; color: #2563eb; font-weight: bold; }
        QFrame#PreviewContainer { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px; }
        QTextEdit#PreviewText { background-color: #ffffff; color: #0f172a; border: 1px solid #cbd5e1; border-radius: 6px; font-family: "Consolas", monospace; font-size: 13px; }
        QToolBar { background-color: #f8fafc; border-bottom: 1px solid #e2e8f0; spacing: 8px; padding: 6px; }
        QPushButton { background-color: #ffffff; color: #0f172a; border: 1px solid #cbd5e1; border-radius: 6px; padding: 6px 12px; }
        QPushButton:hover { background-color: #2563eb; color: #ffffff; }
        QComboBox { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 4px 8px; color: #0f172a; }
    """
}

TRANSLATIONS = {
    "FR": {
        "title": "Körün — Gestionnaire de fichiers Portable",
        "preview_title": "Aperçu du fichier",
        "preview_empty": "Sélectionnez un fichier pour afficher son aperçu.",
        "toggle_preview": "⇄ Aperçu",
        "settings": "⚙ Paramètres",
        "check_update": "🔄 MAJ",
        "about": "ℹ À propos",
        "up_dir": "⬆ Remonter",
        "tree_title": "Arborescence Système"
    },
    "EN": {
        "title": "Körün — Portable File Manager",
        "preview_title": "File Preview",
        "preview_empty": "Select a file to preview its content.",
        "toggle_preview": "⇄ Preview",
        "settings": "⚙ Settings",
        "check_update": "🔄 Update",
        "about": "ℹ About",
        "up_dir": "⬆ Up",
        "tree_title": "System Tree"
    },
    "TR": {
        "title": "Körün — Taşınabilir Dosya Yöneticisi",
        "preview_title": "Dosya Önizleme",
        "preview_empty": "Önizlemek için bir dosya seçin.",
        "toggle_preview": "⇄ Önizleme",
        "settings": "⚙ Ayarlar",
        "check_update": "🔄 Güncelle",
        "about": "ℹ Hakkında",
        "up_dir": "⬆ Yukarı",
        "tree_title": "Sistem Ağacı"
    },
    "AR": {
        "title": "Körün — مدير الملفات المحمول",
        "preview_title": "معاينة الملف",
        "preview_empty": "حدد ملفًا لفرض معاينته.",
        "toggle_preview": "⇄ المعاينة",
        "settings": "⚙ الإعدادات",
        "check_update": "🔄 التحديث",
        "about": "ℹ حول",
        "up_dir": "⬆ للأعلى",
        "tree_title": "شجرة النظام"
    }
}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                return {**DEFAULT_CONFIG, **json.load(f)}
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()

def save_config(config):
    try:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=4)
    except Exception:
        pass

class SettingsDialog(QDialog):
    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Paramètres — Körün")
        self.setFixedWidth(380)
        self.config = config.copy()

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["FR", "EN", "TR", "AR"])
        self.combo_lang.setCurrentText(self.config["language"])
        form.addRow("Langue / Language :", self.combo_lang)

        self.combo_theme = QComboBox()
        self.combo_theme.addItems(list(THEMES.keys()))
        self.combo_theme.setCurrentText(self.config["theme"])
        form.addRow("Thème visuel :", self.combo_theme)

        self.chk_tree = QCheckBox("Afficher l'arborescence latérale")
        self.chk_tree.setChecked(self.config["show_tree"])
        form.addRow(self.chk_tree)

        self.chk_update = QCheckBox("Vérifier les MAJ au démarrage")
        self.chk_update.setChecked(self.config["auto_check_updates"])
        form.addRow(self.chk_update)

        layout.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def get_settings(self):
        return {
            "language": self.combo_lang.currentText(),
            "theme": self.combo_theme.currentText(),
            "show_tree": self.chk_tree.isChecked(),
            "auto_check_updates": self.chk_update.isChecked()
        }

class FilePanel(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(2, 2, 2, 2)

        nav_box = QHBoxLayout()
        self.btn_up = QPushButton("⬆")
        self.btn_up.setFixedWidth(40)
        self.btn_up.clicked.connect(self.go_up)
        nav_box.addWidget(self.btn_up)

        self.path_edit = QLineEdit()
        self.path_edit.returnPressed.connect(self.navigate_to_path)
        nav_box.addWidget(self.path_edit)

        self.layout.addLayout(nav_box)

        self.model = QFileSystemModel()
        self.model.setRootPath(QDir.rootPath())

        self.tree = QTreeView()
        self.tree.setModel(self.model)
        
        home_path = QDir.homePath()
        self.tree.setRootIndex(self.model.index(home_path))
        self.path_edit.setText(home_path)

        self.tree.setAnimated(True)
        self.tree.setIndentation(16)
        self.tree.setSortingEnabled(True)
        self.tree.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)

        self.layout.addWidget(self.tree)

        self.tree.doubleClicked.connect(self.on_double_click)
        self.tree.selectionModel().selectionChanged.connect(self.update_path_display)

    def on_double_click(self, index: QModelIndex):
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

class PreviewWidget(QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("PreviewContainer")
        self.layout = QVBoxLayout(self)

        self.title_label = QLabel("Aperçu")
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

        if ext == '.docx' and HAS_DOCX:
            try:
                doc = docx.Document(file_path)
                text = "\n".join([p.text for p in doc.paragraphs if p.text])
                self.txt_preview.setPlainText(text[:5000])
                self.stack.setCurrentIndex(2)
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
        self.config = load_config()
        self.apply_theme()
        self.resize(1350, 850)

        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)

        # Arborescence globale latérale
        self.global_model = QFileSystemModel()
        self.global_model.setRootPath(QDir.rootPath())
        self.global_tree = QTreeView()
        self.global_tree.setModel(self.global_model)
        self.global_tree.setHeaderHidden(True)
        self.global_tree.setColumnHidden(1, True)
        self.global_tree.setColumnHidden(2, True)
        self.global_tree.setColumnHidden(3, True)

        self.panel_left = FilePanel()
        self.panel_right = FilePanel()

        self.panels_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.panels_splitter.addWidget(self.panel_left)
        self.panels_splitter.addWidget(self.panel_right)

        self.preview = PreviewWidget()

        self.main_splitter.addWidget(self.global_tree)
        self.main_splitter.addWidget(self.panels_splitter)
        self.main_splitter.addWidget(self.preview)
        self.main_splitter.setSizes([220, 750, 380])

        self.setCentralWidget(self.main_splitter)

        self.global_tree.doubleClicked.connect(self.on_global_tree_click)
        self.panel_left.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_left.get_selected_path())
        )
        self.panel_right.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_right.get_selected_path())
        )

        self.create_toolbar()
        self.retranslate_ui()
        self.update_visibility()

    def apply_theme(self):
        style = THEMES.get(self.config["theme"], THEMES["Catppuccin Macchiato"])
        self.setStyleSheet(style)

    def create_toolbar(self):
        self.toolbar = QToolBar("Barre principale")
        self.addToolBar(self.toolbar)

        self.btn_toggle_preview = QPushButton()
        self.btn_toggle_preview.clicked.connect(self.toggle_preview_position)
        self.toolbar.addWidget(self.btn_toggle_preview)

        self.toolbar.addSeparator()

        self.btn_settings = QPushButton()
        self.btn_settings.clicked.connect(self.open_settings)
        self.toolbar.addWidget(self.btn_settings)

        self.btn_about = QPushButton()
        self.btn_about.clicked.connect(self.show_about)
        self.toolbar.addWidget(self.btn_about)

    def open_settings(self):
        dialog = SettingsDialog(self.config, self)
        if dialog.exec():
            self.config = dialog.get_settings()
            save_config(self.config)
            self.apply_theme()
            self.retranslate_ui()
            self.update_visibility()

    def update_visibility(self):
        self.global_tree.setVisible(self.config["show_tree"])

    def on_global_tree_click(self, index: QModelIndex):
        if self.global_model.isDir(index):
            path = self.global_model.filePath(index)
            self.panel_left.path_edit.setText(path)
            self.panel_left.navigate_to_path()

    def retranslate_ui(self):
        t = TRANSLATIONS.get(self.config["language"], TRANSLATIONS["FR"])
        self.setWindowTitle(f"{t['title']} — {CURRENT_VERSION}")
        self.preview.title_label.setText(t["preview_title"])
        self.preview.lbl_empty.setText(t["preview_empty"])
        self.btn_toggle_preview.setText(t["toggle_preview"])
        self.btn_settings.setText(t["settings"])
        self.btn_about.setText(t["about"])
        self.panel_left.btn_up.setText(t["up_dir"])
        self.panel_right.btn_up.setText(t["up_dir"])

    def toggle_preview_position(self):
        if self.main_splitter.indexOf(self.preview) == 2:
            self.main_splitter.insertWidget(1, self.preview)
        else:
            self.main_splitter.addWidget(self.preview)

    def show_about(self):
        QMessageBox.about(
            self,
            "Körün",
            f"<h3>Körün Portable — {CURRENT_VERSION}</h3>"
            "<p>Gestionnaire de fichiers multiplateforme portable.</p>"
            "<hr><p><b>Auteur :</b> David HARPUTOGLU<br><b>Contact :</b> kasparof57@gmail.com<br><b>Licence :</b> MIT</p>"
        )

def main():
    app = QApplication(sys.argv)
    window = KorunApp()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
