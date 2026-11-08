"""Split a large Markdown doc into a folder of section files; the original file stays as the index.

ClientA\\_Documentation\\Context convention (2026-11-06): a doc over ~600 lines becomes
  <Name>.md      - index: the original preamble + a table of the sections (old references keep working)
  <Name>\\NN_<slug>.md - one file per section, content moved verbatim
Headings inside ``` code blocks are ignored. Relative links in moved text get one more "../".

  python Split-DocToFolder.py <file.md> --level 2 [--deep "Section title start" ...] [--keep "Section title start" ...] [--dry]
    --level 2|3   heading level that starts a section file
    --deep T      with --level 2: the section whose title starts with T is split further by its ### headings
    --keep T      section stays in the index file (short meta sections: decisions, run order, status)

Change log:
2026-11-06  (2) ](<file:///...>) links were prefixed with ../ (angle-bracket regex fixed)
2026-11-06  (1) First version
"""
import argparse, os, re, sys, datetime

ap = argparse.ArgumentParser()
ap.add_argument("file")
ap.add_argument("--level", type=int, default=2)
ap.add_argument("--deep", action="append", default=[])
ap.add_argument("--keep", action="append", default=[])
ap.add_argument("--dry", action="store_true")
a = ap.parse_args()

src = os.path.abspath(a.file)
base = os.path.splitext(os.path.basename(src))[0]
folder = os.path.join(os.path.dirname(src), base)
with open(src, encoding="utf-8") as f:
    lines = f.read().split("\n")

# heading scan outside code fences
heads, fence = [], False
for i, l in enumerate(lines):
    if l.lstrip().startswith("```"):
        fence = not fence
        continue
    if not fence:
        m = re.match(r"^(#{2,3}) (.+)$", l)
        if m:
            heads.append((i, len(m.group(1)), m.group(2).strip()))

def starts(title, prefixes):
    return any(title.startswith(p) for p in prefixes)

# section boundaries: level-N headings; for --deep sections also their ### headings
cuts, deep_open = [], False
for i, lv, t in heads:
    if lv == a.level:
        deep_open = a.level == 2 and starts(t, a.deep)
        cuts.append((i, lv, t, deep_open))   # deep parent: its own intro becomes a file too
    elif lv == 3 and deep_open:
        cuts.append((i, lv, t, False))
if not cuts:
    sys.exit("no headings at level %d" % a.level)

pre = lines[:cuts[0][0]]
sections = []
for k, (i, lv, t, isdeep) in enumerate(cuts):
    end = cuts[k + 1][0] if k + 1 < len(cuts) else len(lines)
    sections.append({"start": i, "end": end, "level": lv, "title": t, "body": lines[i:end]})

ABS = r"(?:https?:|#|/|[A-Za-z]:|file:|mailto:)"
link_angle = re.compile(r"\]\(<(?!" + ABS + r")([^>]+)>\)")      # ](<path with spaces>)
link_plain = re.compile(r"\]\((?!<|" + ABS + r")([^)\s]+)\)")     # ](path)
def relink(text):
    text = link_angle.sub(lambda m: "](<../" + m.group(1) + ">)", text)
    return link_plain.sub(lambda m: "](../" + m.group(1) + ")", text)

def slug(t):
    t = re.sub(r"[`*\"'()\[\]]", "", t)
    t = re.sub(r"[^A-Za-z0-9]+", "_", t).strip("_")
    return (t[:48].rstrip("_") or "Section")

index_rows, kept_blocks, n, used = [], [], 0, set()
for s in sections:
    if s["level"] == a.level and starts(s["title"], a.keep):
        kept_blocks.append("\n".join(s["body"]).rstrip("\n"))
        continue
    n += 1
    name = "%02d_%s.md" % (n, slug(s["title"]))
    while name in used:
        name = name.replace(".md", "_x.md")
    used.add(name)
    s["file"] = name
    body = "\n".join(s["body"]).rstrip("\n")
    if s["level"] == 3:   # a ### file starts with a ## heading of its own
        body = body.replace("### ", "## ", 1)
    s["text"] = ("Part of [%s.md](../%s.md) (split 2026-11-06).\n\n" % (base, base)) + relink(body) + "\n"
    indent = "  " if s["level"] == 3 and a.level == 2 else ""
    index_rows.append("%s- [%s](%s/%s) — %d lines" % (indent, s["title"].replace("|", "/"), base, name, s["end"] - s["start"]))

index = "\n".join(pre).rstrip("\n") + "\n\n"
index += ("> **Split into the folder `%s\\` on 2026-11-06** — this file is the index, the content is in the files below "
          "(moved verbatim; an old reference \"%s.md → <section>\" finds the section by its title here). "
          "New content goes into the section file, a new section = a new file + a line here. "
          "Convention: `README.md` of this folder's parent.\n\n" % (base, base))
if kept_blocks:
    index += "\n\n".join(kept_blocks) + "\n\n"
index += "## Sections\n\n" + "\n".join(index_rows) + "\n"

moved = sum(s["end"] - s["start"] for s in sections if "file" in s)
print("%s: %d lines -> index %d lines + %d files (%d lines moved)" % (base, len(lines), index.count("\n"), n, moved))
if a.dry:
    for r in index_rows: print("  " + r)
    sys.exit()
os.makedirs(folder, exist_ok=False)
for s in sections:
    if "file" in s:
        with open(os.path.join(folder, s["file"]), "w", encoding="utf-8", newline="\n") as f:
            f.write(s["text"])
with open(src, "w", encoding="utf-8", newline="\n") as f:
    f.write(index)
