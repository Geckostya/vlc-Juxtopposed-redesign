#!/usr/bin/env python3
"""Rewrites the list of redesign QML files in modules/gui/qt/meson.build and Makefile.am
from the content of modules/gui/qt/redesign/qml (run it after adding or removing a file).

  python redesign-dev/tools/sync_qml_lists.py
"""
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'modules', 'gui', 'qt')
SINGLETONS = ['Theme.qml', 'RWindows.qml']


def main():
    qml_dir = os.path.join(ROOT, 'redesign', 'qml')
    files = sorted(f for f in os.listdir(qml_dir) if f.endswith('.qml') and f not in SINGLETONS)
    singletons = sorted(SINGLETONS)

    path = os.path.join(ROOT, 'meson.build')
    with open(path, encoding='utf-8', newline='') as f:
        s = f.read()
    nl = '\r\n' if '\r\n' in s else '\n'
    block = re.compile(r"(    'outdir' : 'VLC/Redesign',\r?\n    'sources': files\(\r?\n)(.*?)(    \),\r?\n    'singletons': files\(\r?\n)(.*?)(    \),)", re.S)
    m = block.search(s)
    assert m, 'redesign block not found in meson.build'
    sources = ''.join(f"        'redesign/qml/{x}',{nl}" for x in files)
    singles = ''.join(f"        'redesign/qml/{x}',{nl}" for x in singletons)
    s = s[:m.start()] + m.group(1) + sources + m.group(3) + singles + m.group(5) + s[m.end():]
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(s)

    path = os.path.join(ROOT, 'Makefile.am')
    with open(path, encoding='utf-8', newline='') as f:
        s = f.read()
    nl = '\r\n' if '\r\n' in s else '\n'
    block = re.compile(r"(libqml_module_redesign_a_QML = \\\r?\n)(.*?)(libqml_module_redesign_a_Singleton_QML = \\\r?\n)(.*?)(libqml_module_redesign_a_SOURCES)", re.S)
    m = block.search(s)
    assert m, 'redesign block not found in Makefile.am'

    def lst(items):
        return (' \\' + nl).join('\tredesign/qml/' + x for x in items) + nl

    s = s[:m.start()] + m.group(1) + lst(files) + m.group(3) + lst(singletons) + m.group(5) + s[m.end():]
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(s)
    print(f'{len(files)} files, {len(singletons)} singletons')


if __name__ == '__main__':
    main()
