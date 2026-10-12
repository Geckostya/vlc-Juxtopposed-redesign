#!/usr/bin/env python3
"""Split the Figma "Icon" frame export (FigmaExport/Icon.svg) into one SVG per icon
and recolor them for the redesign icon provider.

usage: split_icons.py <Icon.svg> <out dir>
needs: pip install svgelements

icon-cells.json lists every icon of the frame (Figma node 42:356) with its
position, it comes from the Figma metadata of the file.
Colors: accent (#D37918 family) -> #FF8800, everything else -> #FF00FF,
the QML side recolors them at runtime (RedesignIconProvider).
After running it, apply the renames listed at the bottom (same as in the repo).
"""
import json, os, re, sys
import xml.etree.ElementTree as ET
from svgelements import SVG, Shape

src, out = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
cells = []
for c in json.load(open(os.path.join(here, 'icon-cells.json'))):
    n = c['name'].replace(' ', '-')
    if c['direction'] != 'default': n += '_' + c['direction']
    if c['state'] != 'default': n += '_' + c['state']
    if c['value'] != 'default': n += '_' + c['value']
    if c['EQ'] != 'default': n += '_' + c['EQ'].replace(' ', '-')
    if c['two_tone'] == 'yes': n += '_2t'
    cells.append((n, c['x'], c['y']))

ns = '{http://www.w3.org/2000/svg}'
ET.register_namespace('', 'http://www.w3.org/2000/svg')
root = ET.parse(src).getroot()
shapes = [e for e in SVG.parse(src).elements() if isinstance(e, Shape)]
defs = [c for c in root if c.tag == ns + 'defs']
raw = [c for c in root if c.tag != ns + 'defs']
assert len(raw) == len(shapes)

buckets = {c[0]: [] for c in cells}
for r, e in zip(raw, shapes):
    bb = e.bbox()
    if bb is None:
        continue
    cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
    for n, x, y in cells:
        if x - 2 <= cx <= x + 26 and y - 2 <= cy <= y + 26:
            buckets[n].append(r)
            break

ACCENT = {'#D37918', '#E8851A', '#C2711A', '#AB6314'}
def recolor(s):
    def rep(m):
        c = m.group(2).upper()
        if c == 'NONE' or c.startswith('URL'):
            return m.group(0)
        return '%s="%s"' % (m.group(1), '#FF8800' if c in ACCENT else '#FF00FF')
    return re.sub(r'(fill|stroke|stop-color)="([^"]*)"', rep, s)

# zero length round-capped segments (dots) are not drawn by QtSvg: use circles
DOT = re.compile(r'<path[^>]*?d="M([\d.]+) ([\d.]+)L([\d.]+) ([\d.]+)"[^>]*?stroke="([^"]+)" stroke-width="([\d.]+)"[^>]*?/>')
def dots(s):
    def rep(m):
        x1, y1, x2, y2 = map(float, m.group(1, 2, 3, 4))
        if abs(x1 - x2) < 0.05 and abs(y1 - y2) < 0.05:
            return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (x1, y1, float(m.group(6)) / 2, m.group(5))
        return m.group(0)
    return DOT.sub(rep, s)

os.makedirs(out, exist_ok=True)
for n, x, y in cells:
    if not buckets[n]:
        print('empty cell:', n)
        continue
    body = ''.join(ET.tostring(r, encoding='unicode') for r in buckets[n])
    d = ''.join(ET.tostring(x_, encoding='unicode') for x_ in defs) if 'url(#' in body else ''
    s = '<svg width="24" height="24" viewBox="%d %d 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">%s%s</svg>' % (x, y, body, d)
    s = s.replace('ns0:', '').replace(' xmlns:ns0="http://www.w3.org/2000/svg"', '')
    open(os.path.join(out, n + '.svg'), 'w').write(dots(recolor(s)))

# renames used by the QML code
for a, b in [('shuffle_right', 'shuffle'), ('repeat_right', 'repeat'), ('close_none', 'volume_mute'),
             ('close_medium', 'volume_medium'), ('close_low', 'volume_low'), ('check_active', 'check')]:
    p = os.path.join(out, a + '.svg')
    if os.path.exists(p):
        os.replace(p, os.path.join(out, b + '.svg'))
# NOTE: logo, tab_*, vol_cone_*, repeat_one, trash, media, playing come from other frames
#       or were drawn by hand, they are kept in the repo as is.
