#!/usr/bin/env python3
"""Sets Godot import options for the painted art (run after `godot --import`):
WebP art (rooms, backgrounds, characters, album, avatars) -> Lossy, quality
0.9, so the store builds stay small; PNG UI pieces stay lossless. Then run
`godot --headless --path . --import` again."""
import glob, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
n = 0
for f in glob.glob(os.path.join(ROOT, "assets/art/**/*.webp.import"), recursive=True):
    s = open(f).read()
    t = re.sub(r"compress/mode=\d", "compress/mode=1", s)
    t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=0.9", t)
    if t != s:
        open(f, "w").write(t)
        n += 1
print(n, "import files set to lossy")
