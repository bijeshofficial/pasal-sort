#!/usr/bin/env python3
"""Collects every user-visible string into data/i18n/strings.csv.

Run from the project root:  python3 tools/i18n_extract.py [--merge DIR]
--merge DIR: also read DIR/*.json ({english: nepali}) into the "ne" column.
- Code: tr("..."), UIKit.t("..."), _t("..."), toast/label/title/button/say
  literals and "title"/"body"/"text" in popup specs.
- Data: names, descriptions and story lines from data/*.json.
Existing translations in the CSV are kept; new keys get an empty "ne".
Columns: keys, en, ne, _review (ignored by Godot: notes for translators).
"""
import csv, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "data", "i18n", "strings.csv")

CODE_PATTERNS = [
    r'(?<![\w.])tr\("((?:[^"\\]|\\.)+)"\)',
    r'UIKit\.t\("((?:[^"\\]|\\.)+)"\)',
    r'(?<![\w.])_t\("((?:[^"\\]|\\.)+)"\)',
    r'VFXManager\.toast\("((?:[^"\\]|\\.)+)"',
    r'UIKit\.(?:label|title|button|ribbon)\("((?:[^"\\]|\\.)+)"',
    r'(?<![\w.])say\("((?:[^"\\]|\\.)+)"\)',
    r'"(?:title|body|text)": "((?:[^"\\]|\\.)+)"',
    r'Popups\.confirm\("((?:[^"\\]|\\.)+)", "((?:[^"\\]|\\.)+)", "((?:[^"\\]|\\.)+)"',
    r'\["[a-z_]+", "([A-Z][^"]+)"(?:, "[a-z_]+")?\]',
]
SKIP = {"", "+", "x", "?"}


def from_code():
    found = {}
    for base, _, files in os.walk(os.path.join(ROOT, "scripts")):
        for f in files:
            if not f.endswith(".gd"):
                continue
            text = open(os.path.join(base, f), encoding="utf-8").read()
            for pat in CODE_PATTERNS:
                for m in re.finditer(pat, text):
                    for g in m.groups():
                        if g and g not in SKIP and not g.startswith("res://") and re.search(r"[A-Za-z]", g):
                            found.setdefault(g.encode().decode("unicode_escape"), "ui")
    return found


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def from_data():
    found = {}
    def add(s, kind="ui"):
        if isinstance(s, str) and s.strip() and re.search(r"[A-Za-z]", s):
            found.setdefault(s, kind)
    eco = load("economy.json")
    for c in eco.get("cosmetics", []): add(c["name"])
    for c in eco.get("cosmetic_categories", []): add(c["name"])
    for b in eco.get("bundles", []): add(b["name"])
    for p in load("iap_products.json")["products"]: add(p["name"])
    for a in load("achievements.json")["achievements"]:
        add(a["title"]); add(a["desc"])
    meta = load("meta.json")
    for t in meta.get("tips", []): add(t)
    for c in meta.get("cheers", []): add(c)
    for a in meta.get("avatars", []): add(a["name"])
    diff = load("difficulty.json")
    for t in diff["twists"].values():
        add(t.get("title")); add(t.get("text"))
    for k in ("label",):
        for t in diff["tiers"].values(): add(t.get(k))
    daily = load("daily.json")
    for m in daily["missions"]: add(m["text"])
    al = load("album.json")
    for p in al["shop"]: add(p["name"])
    for s in al["sets"]:
        add(s["name"])
        for st in s["stickers"]: add(st["name"])
    for c in load("candies.json")["candies"]: add(c.get("name"))
    adir = os.path.join(ROOT, "data", "areas")
    for f in sorted(os.listdir(adir)):
        a = json.load(open(os.path.join(adir, f), encoding="utf-8"))
        add(a["name"]); add(a.get("subtitle"))
        for t in a["tasks"]:
            add(t["name"]); add(t["desc"])
            for st in t["styles"]: add(st["name"])
    sdir = os.path.join(ROOT, "data", "story")
    for f in sorted(os.listdir(sdir)):
        s = json.load(open(os.path.join(sdir, f), encoding="utf-8"))
        for lines in s["lines"].values():
            for line in lines: add(line["text"], "story")
    for name in ("Maya", "Hajurama", "Bhai", "Kanchha Dai", "Sunita Didi", "Biralo"):
        add(name)
    return found


def load_merge():
    merged = {}
    if "--merge" in sys.argv:
        d = sys.argv[sys.argv.index("--merge") + 1]
        for f in sorted(os.listdir(d)):
            if f.endswith(".json") and not f.startswith("batch_"):
                merged.update(json.load(open(os.path.join(d, f), encoding="utf-8")))
    return merged


def placeholders(s):
    return sorted(re.findall(r"%0?\d*[ds%]|\{n\}", s))


def main():
    merged = load_merge()
    rows = {}
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                rows[r["keys"]] = r
    found = {}
    found.update(from_data())
    for k, v in from_code().items():
        found.setdefault(k, v)
    out = []
    for key, kind in sorted(found.items(), key=lambda kv: (kv[1] != "ui", kv[0].lower())):
        old = rows.get(key, {})
        review = old.get("_review", "") or ("story: needs native review" if kind == "story" else "")
        ne = merged.get(key, old.get("ne", ""))
        if ne and placeholders(ne) != placeholders(key):
            print("placeholder mismatch, kept English:", repr(key), "->", repr(ne))
            ne = key
        out.append({"keys": key, "en": key, "ne": ne, "_review": review})
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["keys", "en", "ne", "_review"], quoting=csv.QUOTE_MINIMAL)
        w.writeheader()
        w.writerows(out)
    missing = sum(1 for r in out if not r["ne"])
    print("%d strings (%d ui, %d story), %d without Nepali" % (len(out), sum(1 for r in out if found[r["keys"]] == "ui"), sum(1 for r in out if found[r["keys"]] == "story"), missing))


if __name__ == "__main__":
    main()
