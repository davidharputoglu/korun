#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Körün — Cross-platform dual-pane file manager
Author: David HARPUTOGLU
Version: 0.1.5
License: MIT
"""

import sys
import os
import subprocess
import tempfile
import requests
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
    QTreeView, QSplitter, QLabel, QPushButton, QToolBar, QMessageBox,
    QTextEdit, QStackedWidget, QFrame, QHeaderView, QComboBox, QLineEdit
)
from PyQt6.QtCore import Qt, QDir, QSize, QThread, pyqtSignal, QModelIndex
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

CURRENT_VERSION = "v0.1.5"
GITHUB_REPO = "davidharputoglu/korun"

TRANSLATIONS = {
    "FR": {
        "title": "Körün — Gestionnaire de fichiers",
        "preview_title": "Aperçu du fichier",
        "preview_empty": "Sélectionnez un fichier pour afficher son aperçu.",
        "toggle_preview": "⇄ Inverser l'aperçu",
        "check_update": "🔄 Vérifier MAJ",
        "about": "ℹ À propos",
        "update_available": "Mise à jour disponible",
        "update_latest": "Vous utilisez déjà la dernière version ({}) !",
        "update_msg": "Une nouvelle version ({}) est disponible !\n\nSouhaitez-vous ouvrir la page de téléchargement ?",
        "lang_label": "Langue :",
        "up_dir": "⬆ Remonter",
        "rtl": False
    },
    "AR": {
        "title": "Körün — مدير الملفات",
        "preview_title": "معاينة الملف",
        "preview_empty": "حدد ملفًا لفرض معاينته.",
        "toggle_preview": "⇄ تبديل لوحة المعاينة",
        "check_update": "🔄 التحقق من التحديثات",
        "about": "ℹ حول البرنامج",
        "update_available": "تحديث متاح",
        "update_latest": "أنت تستخدم أحدث إصدار ({}) بالفعل!",
        "update_msg": "يتوفر إصدار جديد ({})!\n\nهل ترغب في فتح صفحة التنزيل؟",
        "lang_label": "اللغة:",
        "up_dir": "⬆ للأعلى",
        "rtl": True
    },
    "EN": {
        "title": "Körün — File Manager",
        "preview_title": "File Preview",
        "preview_empty": "Select a file to preview its content.",
        "toggle_preview": "⇄ Toggle Preview",
        "check_update": "🔄 Check Updates",
        "about": "ℹ About",
        "update_available": "Update Available",
        "update_latest": "You are using the latest version ({})!",
        "update_msg": "A new version ({}) is available!\n\nWould you like to open the release page?",
        "lang_label": "Language:",
        "up_dir": "⬆ Up",
        "rtl": False
    },
    "TR": {
        "title": "Körün — Dosya Yöneticisi",
        "preview_title": "Dosya Önizleme",
        "preview_empty": "Önizlemek için bir dosya seçin.",
        "toggle_preview": "⇄ Önizleme Konumu",
        "check_update": "🔄 Güncellemeleri Denetle",
        "about": "ℹ Hakkında",
        "update_available": "Güncelleme Mevcut",
        "update_latest": "Zaten en son sürümü ({}) kullanıyorsunuz!",
        "update_msg": "Yeni bir sürüm ({}) mevcut!\n\nİndirme sayfasını açmak ister misiniz?",
        "lang_label": "Dil:",
        "up_dir": "⬆ Yukarı",
        "rtl": False
    }
}

PROFESSIONAL_STYLE = """
QMainWindow {
    background-color: #12131c;
}
QWidget {
    color: #ffffff;
    font-family: "Segoe UI", "Ubuntu", sans-serif;
    font-size: 13px;
}
QSplitter::handle {
    background-color: #252836;
    width: 3px;
}
QSplitter::handle:hover {
    background-color: #3b82f6;
}
QTreeView {
    background-color: #1a1c29;
    border: 1px solid #2d3142;
    border-radius: 6px;
    padding: 4px;
    outline: none;
    color: #ffffff;
}
QTreeView::item {
    padding: 6px 4px;
    border-radius: 4px;
}
QTreeView::item:hover {
    background-color: #252836;
}
QTreeView::item:selected {
    background-color: #2563eb;
    color: #ffffff;
    font-weight: bold;
}
QHeaderView::section {
    background-color: #1a1c29;
    color: #94a3b8;
    padding: 8px;
    border: none;
    border-bottom: 2px solid #2d3142;
    font-weight: bold;
}
QLineEdit {
    background-color: #1a1c29;
    border: 1px solid #2d3142;
    border-radius: 6px;
    padding: 6px 10px;
    color: #60a5fa;
    font-family: "Consolas", "Monospace";
    font-weight: bold;
}
QFrame#PreviewContainer {
    background-color: #1a1c29;
    border: 1px solid #2d3142;
    border-radius: 6px;
    padding: 12px;
}
QLabel#PreviewTitle {
    font-size: 14px;
    font-weight: bold;
    color: #60a5fa;
    padding-bottom: 8px;
    border-bottom: 1px solid #2d3142;
}
QTextEdit#PreviewText {
    background-color: #ffffff;
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    color: #0f172a;
    font-family: "Consolas", "Monospace";
    font-size: 13px;
    padding: 10px;
}
QToolBar {
    background-color: #12131c;
    border-bottom: 1px solid #2d3142;
    spacing: 8px;
    padding: 6px;
}
QPushButton {
    background-color: #252836;
    color: #ffffff;
    border: 1px solid #3b4252;
    border-radius: 6px;
    padding: 6px 14px;
    font-weight: 600;
}
QPushButton:hover {
    background-color: #3b82f6;
    border-color: #60a5fa;
    color: #ffffff;
}
QComboBox {
    background-color: #252836;
    border: 1px solid #3b4252;
    border-radius: 6px;
    padding: 5px 10px;
    color: #ffffff;
    font-weight: bold;
}
"""

class UpdateCheckerThread(QThread):
    update_signal = pyqtSignal(str, str, bool)

    def __init__(self, manual_check=False):
        super().__init__()
        self.manual_check = manual_check

    def run(self):
        try:
            url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
            res = requests.get(url, timeout=5)
            if res.status_code == 200:
                data = res.json()
                latest_tag = data.get("tag_name", "")
                html_url = data.get("html_url", "")
                if latest_tag and latest_tag != CURRENT_VERSION:
                    self.update_signal.emit(latest_tag, html_url, True)
                else:
                    if self.manual_check:
                        self.update_signal.emit(CURRENT_VERSION, "", False)
        except Exception:
            pass

class FilePanel(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(4, 4, 4, 4)

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

        if ext == '.docx' and HAS_DOCX:
            try:
                doc = docx.Document(file_path)
                text = "\n".join([p.text for p in doc.paragraphs if p.text])
                self.txt_preview.setPlainText(text[:5000])
                self.stack.setCurrentIndex(2)
                return
            except Exception:
                pass

        if ext == '.xlsx' and HAS_OPENPYXL:
            try:
                wb = openpyxl.load_workbook(file_path, data_only=True)
                sheet = wb.active
                lines = []
                for row in sheet.iter_rows(max_row=30, values_only=True):
                    row_str = " | ".join([str(val) if val is not None else "" for val in row])
                    if row_str.strip():
                        lines.append(row_str)
                self.txt_preview.setPlainText("\n".join(lines))
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
        self.current_lang = "FR"
        self.setStyleSheet(PROFESSIONAL_STYLE)
        self.resize(1280, 800)

        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.panel_left = FilePanel()
        self.panel_right = FilePanel()

        self.panels_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.panels_splitter.addWidget(self.panel_left)
        self.panels_splitter.addWidget(self.panel_right)

        self.preview = PreviewWidget()

        self.main_splitter.addWidget(self.panels_splitter)
        self.main_splitter.addWidget(self.preview)
        self.main_splitter.setSizes([850, 430])

        self.setCentralWidget(self.main_splitter)

        self.panel_left.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_left.get_selected_path())
        )
        self.panel_right.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_right.get_selected_path())
        )

        self.create_toolbar()
        self.retranslate_ui()

        self.auto_check_update()

    def create_toolbar(self):
        self.toolbar = QToolBar("Barre principale")
        self.addToolBar(self.toolbar)

        self.btn_toggle_preview = QPushButton()
        self.btn_toggle_preview.clicked.connect(self.toggle_preview_position)
        self.toolbar.addWidget(self.btn_toggle_preview)

        self.toolbar.addSeparator()

        self.btn_check_update = QPushButton()
        self.btn_check_update.clicked.connect(self.manual_check_update)
        self.toolbar.addWidget(self.btn_check_update)

        self.toolbar.addSeparator()

        self.lbl_lang = QLabel("Langue :")
        self.toolbar.addWidget(self.lbl_lang)

        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["FR", "AR", "EN", "TR"])
        self.combo_lang.currentTextChanged.connect(self.change_language)
        self.toolbar.addWidget(self.combo_lang)

        self.toolbar.addSeparator()

        self.btn_about = QPushButton()
        self.btn_about.clicked.connect(self.show_about)
        self.toolbar.addWidget(self.btn_about)

    def change_language(self, lang_code):
        self.current_lang = lang_code
        self.retranslate_ui()

    def retranslate_ui(self):
        t = TRANSLATIONS.get(self.current_lang, TRANSLATIONS["FR"])
        self.setWindowTitle(f"{t['title']} — {CURRENT_VERSION}")
        self.preview.title_label.setText(t["preview_title"])
        self.preview.lbl_empty.setText(t["preview_empty"])
        self.btn_toggle_preview.setText(t["toggle_preview"])
        self.btn_check_update.setText(t["check_update"])
        self.btn_about.setText(t["about"])
        self.lbl_lang.setText(t["lang_label"])
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

    def auto_check_update(self):
        self.update_thread = UpdateCheckerThread(manual_check=False)
        self.update_thread.update_signal.connect(self.prompt_update)
        self.update_thread.start()

    def manual_check_update(self):
        self.update_thread_manual = UpdateCheckerThread(manual_check=True)
        self.update_thread_manual.update_signal.connect(self.prompt_update)
        self.update_thread_manual.start()

    def prompt_update(self, latest_tag, url, available):
        t = TRANSLATIONS.get(self.current_lang, TRANSLATIONS["FR"])
        if available:
            reply = QMessageBox.question(
                self,
                t["update_available"],
                t["update_msg"].format(latest_tag),
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if reply == QMessageBox.StandardButton.Yes:
                import webbrowser
                webbrowser.open(url)
        else:
            QMessageBox.information(
                self,
                t["title"],
                t["update_latest"].format(CURRENT_VERSION)
            )

    def show_about(self):
        QMessageBox.about(
            self,
            "Körün",
            f"<h3>Körün — {CURRENT_VERSION}</h3>"
            "<p>Gestionnaire de fichiers multiplateforme à double panneau.</p>"
            "<hr><p><b>Auteur :</b> David HARPUTOGLU<br><b>Contact :</b> kasparof57@gmail.com<br><b>Licence :</b> MIT</p>"
        )

def main():
    app = QApplication(sys.argv)
    window = KorunApp()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
