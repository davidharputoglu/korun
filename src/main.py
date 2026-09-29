#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Körün - Gestionnaire de fichiers à double panneau avec aperçu latéral
Auteur: David HARPUTOGLU (assisté par IA)
Contact: kasparof57@gmail.com
Version: 0.1.1
Licence: MIT
"""

import sys
import os
import shutil
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
    QTreeView, QFileSystemModel, QSplitter, QLabel, QPushButton,
    QToolBar, QMessageBox, QTextEdit, QStackedWidget, QFrame, QHeaderView
)
from PyQt6.QtCore import Qt, QDir, QSize
from PyQt6.QtGui import QPixmap, QAction, QFont, QColor

try:
    import PyPDF2
    HAS_PYPDF = True
except ImportError:
    HAS_PYPDF = False

MODERN_STYLE = """
QMainWindow {
    background-color: #1e1e2e;
}
QWidget {
    color: #cdd6f4;
    font-family: "Segoe UI", "Ubuntu", "Cantarell", sans-serif;
    font-size: 13px;
}
QSplitter::handle {
    background-color: #313244;
    width: 2px;
    height: 2px;
}
QSplitter::handle:hover {
    background-color: #89b4fa;
}
QTreeView {
    background-color: #181825;
    border: 1px solid #313244;
    border-radius: 8px;
    outline: none;
    padding: 4px;
}
QTreeView::item {
    padding: 6px;
    border-radius: 4px;
}
QTreeView::item:hover {
    background-color: #313244;
}
QTreeView::item:selected {
    background-color: #45475a;
    color: #89b4fa;
    font-weight: bold;
}
QHeaderView::section {
    background-color: #181825;
    color: #a6adc8;
    padding: 6px;
    border: none;
    font-weight: bold;
    border-bottom: 1px solid #313244;
}
QFrame#PreviewContainer {
    background-color: #181825;
    border: 1px solid #313244;
    border-radius: 8px;
    padding: 12px;
}
QLabel#PreviewTitle {
    font-size: 14px;
    font-weight: bold;
    color: #89b4fa;
    padding-bottom: 8px;
    border-bottom: 1px solid #313244;
}
QTextEdit#PreviewText {
    background-color: #1e1e2e;
    border: 1px solid #313244;
    border-radius: 6px;
    color: #a6adc8;
    font-family: "JetBrains Mono", "Consolas", "Monospace";
    font-size: 12px;
}
QToolBar {
    background-color: #1e1e2e;
    border-bottom: 1px solid #313244;
    spacing: 8px;
    padding: 6px;
}
QPushButton {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 6px;
    padding: 6px 14px;
    font-weight: 500;
}
QPushButton:hover {
    background-color: #45475a;
    border-color: #89b4fa;
    color: #ffffff;
}
QPushButton:pressed {
    background-color: #89b4fa;
    color: #11111b;
}
"""

class FilePanel(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(4, 4, 4, 4)

        self.model = QFileSystemModel()
        self.model.setRootPath(QDir.rootPath())

        self.tree = QTreeView()
        self.tree.setModel(self.model)
        self.tree.setRootIndex(self.model.index(QDir.homePath()))
        self.tree.setAnimated(True)
        self.tree.setIndentation(18)
        self.tree.setSortingEnabled(True)
        
        self.tree.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.tree.header().setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)

        self.layout.addWidget(self.tree)

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

        self.lbl_empty = QLabel("Sélectionnez un fichier pour prévisualiser son contenu.")
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
            self.lbl_empty.setText("Sélectionnez un fichier valide.")
            self.stack.setCurrentIndex(0)
            return

        ext = os.path.splitext(file_path)[1].lower()

        if ext in ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.svg']:
            pixmap = QPixmap(file_path)
            if not pixmap.isNull():
                scaled = pixmap.scaled(380, 380, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                self.lbl_image.setPixmap(scaled)
                self.stack.setCurrentIndex(1)
                return

        if ext in ['.txt', '.md', '.py', '.json', '.xml', '.html', '.css', '.js', '.sh', '.conf', '.ini']:
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read(6000)
                self.txt_preview.setPlainText(content)
                self.stack.setCurrentIndex(2)
                return
            except Exception:
                pass

        if ext == '.pdf' and HAS_PYPDF:
            try:
                reader = PyPDF2.PdfReader(file_path)
                text = f"📄 Document PDF ({len(reader.pages)} pages)\n"
                text += "=" * 40 + "\n\n"
                if len(reader.pages) > 0:
                    text += reader.pages[0].extract_text()[:3000]
                self.txt_preview.setPlainText(text)
                self.stack.setCurrentIndex(2)
                return
            except Exception:
                pass

        self.lbl_empty.setText(f"Aperçu direct indisponible pour :\n\n<b>{os.path.basename(file_path)}</b>")
        self.stack.setCurrentIndex(0)

class KorunApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Körün — v0.1.1")
        self.resize(1200, 750)

        self.setStyleSheet(MODERN_STYLE)

        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)

        self.panel_left = FilePanel()
        self.panel_right = FilePanel()

        self.panels_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.panels_splitter.addWidget(self.panel_left)
        self.panels_splitter.addWidget(self.panel_right)

        self.preview = PreviewWidget()

        self.main_splitter.addWidget(self.panels_splitter)
        self.main_splitter.addWidget(self.preview)
        self.main_splitter.setSizes([800, 400])

        self.setCentralWidget(self.main_splitter)

        self.panel_left.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_left.get_selected_path())
        )
        self.panel_right.tree.selectionModel().selectionChanged.connect(
            lambda: self.preview.preview_file(self.panel_right.get_selected_path())
        )

        self.create_toolbar()

    def create_toolbar(self):
        toolbar = QToolBar("Barre principale")
        toolbar.setIconSize(QSize(18, 18))
        self.addToolBar(toolbar)

        btn_toggle_preview = QPushButton("⇄ Inverser Volet Aperçu")
        btn_toggle_preview.clicked.connect(self.toggle_preview_position)
        toolbar.addWidget(btn_toggle_preview)

        toolbar.addSeparator()

        btn_about = QPushButton("ℹ À propos")
        btn_about.clicked.connect(self.show_about)
        toolbar.addWidget(btn_about)

    def toggle_preview_position(self):
        if self.main_splitter.indexOf(self.preview) == 1:
            self.main_splitter.insertWidget(0, self.preview)
        else:
            self.main_splitter.addWidget(self.preview)

    def show_about(self):
        QMessageBox.about(
            self,
            "À propos de Körün",
            "<h3>Körün — v0.1.1</h3>"
            "<p>Gestionnaire de fichiers moderne à double panneau avec aperçu latéral.</p>"
            "<hr>"
            "<p><b>Développeur :</b> David HARPUTOGLU (assisté par IA)<br>"
            "<b>Contact :</b> kasparof57@gmail.com<br>"
            "<b>Licence :</b> MIT</p>"
        )

def main():
    app = QApplication(sys.argv)
    window = KorunApp()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
