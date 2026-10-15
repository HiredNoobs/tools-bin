#!/usr/bin/env python3
"""Previews for Settings › Appearance's icon and cursor galleries, as JSON on stdout:
{"icons": {theme: [file, ...]}, "cursors": {theme: {"pointer": png, "text": png, "hand": png}}}

Icons are a few common ones looked up in each theme (and the themes it inherits from). Cursors
are the arrow, text beam and hand taken out of each theme's X cursor files into PNGs under
~/.cache/quickshell/theme-previews (made again only when the theme's file is newer).
"""

import json
import os
import re
import struct
import sys
import zlib

HOME = os.path.expanduser("~")
ICON_DIRS = ["/usr/share/icons", f"{HOME}/.local/share/icons", f"{HOME}/.icons"]
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or f"{HOME}/.cache", "quickshell", "theme-previews")

# Each preview icon, with names to fall back on
ICONS = [
    ["folder"],
    ["utilities-terminal", "terminal"],
    ["firefox", "web-browser", "internet-web-browser"],
    ["accessories-text-editor", "text-editor"],
    ["preferences-system", "preferences-desktop"],
    ["user-trash"],
]
CURSORS = {
    "pointer": ["left_ptr", "default", "arrow"],
    "text": ["xterm", "text", "ibeam"],
    "hand": ["hand2", "pointer", "hand1", "pointing_hand"],
}
WANTED_SIZE = 48


def theme_dirs(name):
    return [os.path.join(d, name) for d in ICON_DIRS if os.path.isdir(os.path.join(d, name))]


def inherits(name):
    for d in theme_dirs(name):
        try:
            with open(os.path.join(d, "index.theme"), encoding="utf-8", errors="replace") as f:
                for line in f:
                    if line.startswith("Inherits="):
                        return [t.strip() for t in line.split("=", 1)[1].split(",") if t.strip()]
        except OSError:
            pass
    return []


# --- Icons

_indexes = {}


def size_score(path):
    """Lower is better: scalable, then the size nearest 48 (larger first)."""
    if "scalable" in path:
        return 0
    sizes = [int(s) for s in re.findall(r"/(\d+)(?:x\d+)?(?:@\dx)?/", path)]
    if not sizes:
        return 50
    size = sizes[0]
    return abs(size - WANTED_SIZE) + (0.5 if size < WANTED_SIZE else 0)


def index(theme):
    """Icon name -> best file, for one theme (not what it inherits)."""
    if theme in _indexes:
        return _indexes[theme]
    best = {}
    for d in theme_dirs(theme):
        for root, _, files in os.walk(d, followlinks=True):
            if "symbolic" in root:
                continue
            for file in files:
                stem, ext = os.path.splitext(file)
                if ext not in (".svg", ".png") or stem.endswith("-symbolic"):
                    continue
                path = os.path.join(root, file)
                score = size_score(path)
                if stem not in best or score < best[stem][0]:
                    best[stem] = (score, path)
    _indexes[theme] = {name: path for name, (_, path) in best.items()}
    return _indexes[theme]


def lookup(theme, names, seen=None):
    seen = seen or set()
    if theme in seen:
        return None
    seen.add(theme)
    found = index(theme)
    for name in names:
        if name in found:
            return found[name]
    for parent in inherits(theme):
        if parent != "hicolor":
            path = lookup(parent, names, seen)
            if path:
                return path
    return None


# --- Cursors

def read_xcursor(path):
    """The image nearest WANTED_SIZE in an X cursor file, as (width, height, ARGB ints)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        return None
    header, _, count = struct.unpack_from("<III", data, 4)
    images = []
    for i in range(count):
        kind, size, pos = struct.unpack_from("<III", data, header + i * 12)
        if kind == 0xFFFD0002:
            images.append((size, pos))
    if not images:
        return None
    larger = [img for img in images if img[0] >= WANTED_SIZE]
    size, pos = min(larger) if larger else max(images)
    width, height = struct.unpack_from("<II", data, pos + 16)
    pixels = struct.unpack_from(f"<{width * height}I", data, pos + 36)
    return width, height, pixels


def write_png(path, width, height, pixels):
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for argb in pixels[y * width:(y + 1) * width]:
            a = argb >> 24
            r, g, b = (argb >> 16) & 255, (argb >> 8) & 255, argb & 255
            # Stored premultiplied
            if 0 < a < 255:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            rows += bytes((r, g, b, a))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(png)
    os.replace(tmp, path)


def cursor_previews(theme):
    previews = {}
    for d in theme_dirs(theme):
        cursors = os.path.join(d, "cursors")
        if not os.path.isdir(cursors):
            continue
        for role, names in CURSORS.items():
            if role in previews:
                continue
            source = next((os.path.join(cursors, n) for n in names if os.path.exists(os.path.join(cursors, n))), None)
            if not source:
                continue
            target = os.path.join(CACHE, f"{theme}-{role}.png")
            try:
                if not os.path.exists(target) or os.path.getmtime(target) < os.path.getmtime(source):
                    image = read_xcursor(source)
                    if not image:
                        continue
                    write_png(target, *image)
                previews[role] = target
            except (OSError, struct.error):
                continue
    return previews


def main():
    os.makedirs(CACHE, exist_ok=True)
    icon_themes = [t for t in sys.argv[1].split(",") if t] if len(sys.argv) > 1 else []
    cursor_themes = [t for t in sys.argv[2].split(",") if t] if len(sys.argv) > 2 else []
    result = {"icons": {}, "cursors": {}}
    for theme in icon_themes:
        result["icons"][theme] = [p for p in (lookup(theme, names) for names in ICONS) if p]
    for theme in cursor_themes:
        result["cursors"][theme] = cursor_previews(theme)
    json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
