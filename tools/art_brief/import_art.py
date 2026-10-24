#!/usr/bin/env python3
"""Copies the finished art from the art folder into res://assets/art/.

    python3 tools/art_brief/import_art.py [SRC]   (default ~/Downloads/pasal-sort-art)

The source folder is never modified. Paths stay the same (relative to
assets/art/). Small, crisp pieces (UI kit, icons, boosters, candies, jars,
chests, logo, avatar frames) are copied as PNG and imported lossless.
Big painted art is saved as WebP (quality 90) to keep the repo and the
store builds small:
  - areas/: room objects at 1.5x their box (the files are 2x; the Home zoom
    tops out around 1.5-2 screen px per world px), wall/floor plates too;
  - backgrounds/, characters/, album/, avatars/ (except frames): same size.
Then run `godot --headless --path . --import` and tools/art_brief/set_import.py.
"""
import os, sys
from PIL import Image

SRC = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/pasal-sort-art")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DST = os.path.join(ROOT, "assets", "art")
PNG_DIRS = ("ui", "icons", "boosters", "candies", "jars", "chests", "logo", "avatars/frames")


def convert(job):
    rel, src, out, keep_png = job
    im = Image.open(src)
    if keep_png:
        im.save(out, "PNG", optimize=True)
    else:
        if rel.startswith("areas/"):
            w, h = im.size
            im = im.resize((max(1, round(w * 0.75)), max(1, round(h * 0.75))), Image.LANCZOS)
        if im.mode not in ("RGB", "RGBA"):
            im = im.convert("RGBA")
        im.save(out + ".tmp", "WEBP", quality=90, method=4)
        os.replace(out + ".tmp", out)
    return keep_png


if __name__ == "__main__":
    from multiprocessing import Pool
    jobs = []
    for dirpath, _, files in os.walk(SRC):
        rel_dir = os.path.relpath(dirpath, SRC)
        if rel_dir.startswith("_brief") or rel_dir == ".":
            continue
        for f in files:
            if not f.endswith(".png"):
                continue
            rel = os.path.join(rel_dir, f)
            src = os.path.join(SRC, rel)
            keep_png = rel.startswith(PNG_DIRS)
            out = os.path.join(DST, rel if keep_png else rel[:-4] + ".webp")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(src):
                continue
            jobs.append((rel, src, out, keep_png))
    with Pool() as pool:
        res = pool.map(convert, jobs, chunksize=4)
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(DST) for f in fs if not f.endswith(".import"))
    print(f"png {sum(res)}, webp {len(res) - sum(res)} written; assets/art now {total / 1e6:.1f} MB")
