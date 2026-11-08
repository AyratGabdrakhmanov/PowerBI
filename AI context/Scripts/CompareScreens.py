# Compares two screenshots of the same Power BI page (before / after an edit) and prints a short
# text report, so the AI does not have to view whole images:
#   - changed regions (pixel diff on all three color channels - a color change with the same
#     brightness is still found), with their position and share of the page;
#   - for each region: OCR text before/after (only the lines that differ) and the main colors
#     before/after as hex - for color checks;
#   - a side-by-side crop per region (before | after), enlarged if small - view only that crop
#     when the look matters (a few hundred tokens instead of a whole page);
#   - with --expect x0,y0,x1,y1: a WARNING for every change outside the area that was meant to
#     change (side effects).
# Techniques from the lesson-notes pipeline (C:\DAX\Yury\Скрипты_конспектов\prep.py): frame diff on
# downscaled pixels, OCR of only the new lines, cropping + enlargement before reading.
#
# Usage (Python 3.12 with Pillow + numpy):
#   py -3.12 CompareScreens.py before.png after.png [--out DIR] [--expect x0,y0,x1,y1] [--no-ocr]
# Coordinates are pixels of the screenshots (same as OcrImage.ps1 / pbir positions x screenshot
# scale). Both screenshots must have the same size (same page, same --scale).
import argparse
import os
import subprocess
import sys
from collections import Counter

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OCR_PS1 = os.path.join(HERE, "OcrImage.ps1")


def changed_regions(a, b, thr, tile, min_px):
    """Boxes (x0, y0, x1, y1) of changed areas: tile grid -> connected groups of changed tiles."""
    diff = np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2) > thr   # any channel
    H, W = diff.shape
    gh, gw = (H + tile - 1) // tile, (W + tile - 1) // tile
    pad = np.zeros((gh * tile, gw * tile), bool)
    pad[:H, :W] = diff
    grid = pad.reshape(gh, tile, gw, tile).sum(axis=(1, 3)) >= min_px
    seen = np.zeros_like(grid)
    boxes = []
    for gy, gx in zip(*np.nonzero(grid)):
        if seen[gy, gx]:
            continue
        stack, cells = [(gy, gx)], []
        seen[gy, gx] = True
        while stack:                                   # 8-neighbours, 2-tile reach merges nearby text
            y, x = stack.pop()
            cells.append((y, x))
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < gh and 0 <= nx < gw and grid[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        ys = [c[0] for c in cells]
        xs = [c[1] for c in cells]
        box = (min(xs) * tile, min(ys) * tile, min(W, (max(xs) + 1) * tile), min(H, (max(ys) + 1) * tile))
        sub = diff[box[1]:box[3], box[0]:box[2]]
        boxes.append((box, int(sub.sum())))
    return sorted(boxes, key=lambda b: (b[0][1], b[0][0]))


def main_colors(pixels, n=3):
    """Most frequent colors (hex) of an (N, 3) pixel array after light quantization, ignoring <3% shares."""
    if len(pixels) == 0:
        return ["-"]
    q = pixels // 8 * 8
    cnt = Counter(map(tuple, q))
    total = q.shape[0]
    return [f"#{r:02X}{g:02X}{b:02X} {100 * c / total:.0f}%" for (r, g, b), c in cnt.most_common(n) if c / total >= 0.03]


def ocr(path):
    """Text lines via OcrImage.ps1 (Windows PowerShell 5.1); [] if OCR is unavailable."""
    try:
        r = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", OCR_PS1,
                            "-Path", path, "-Upscale", "3"], capture_output=True, text=True, encoding="utf-8", timeout=120)
    except Exception:
        return []
    return [ln.split("|", 2)[2].strip() for ln in r.stdout.splitlines() if ln.count("|") >= 2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--out", help="folder for region crops (default: next to 'after')")
    ap.add_argument("--expect", help="x0,y0,x1,y1 - area that is supposed to change")
    ap.add_argument("--threshold", type=int, default=30, help="per-channel difference that counts as changed")
    ap.add_argument("--pad", type=int, default=12)
    ap.add_argument("--no-ocr", action="store_true")
    ap.add_argument("--max-regions", type=int, default=10,
                    help="details (crop, colors, OCR) only for the N largest regions; the rest - one summary line")
    a = ap.parse_args()

    im_a = Image.open(a.before).convert("RGB")
    im_b = Image.open(a.after).convert("RGB")
    if im_a.size != im_b.size:
        sys.exit(f"Different sizes {im_a.size} vs {im_b.size} - take both screenshots with the same --scale.")
    W, H = im_a.size
    out = a.out or os.path.join(os.path.dirname(os.path.abspath(a.after)), "compare")
    os.makedirs(out, exist_ok=True)
    expect = tuple(int(v) for v in a.expect.split(",")) if a.expect else None

    regions = changed_regions(np.asarray(im_a), np.asarray(im_b), a.threshold, tile=8, min_px=3)
    total = sum(px for _, px in regions)
    print(f"Page {W}x{H}: {len(regions)} changed region(s), {100 * total / (W * H):.2f}% of pixels.")
    if not regions:
        print("No visible change.")
        return

    inside = lambda b: expect and b[0] >= expect[0] and b[1] >= expect[1] and b[2] <= expect[2] and b[3] <= expect[3]
    outside = 0
    # Many regions = a page-wide change (e.g. a slicer stopped filtering): detail only the largest
    if len(regions) > a.max_regions:
        by_size = sorted(regions, key=lambda r: -r[1])
        rest = by_size[a.max_regions:]
        if expect:
            outside = sum(1 for b, _ in rest if not inside(b))
        bx0 = min(b[0] for b, _ in rest); by0 = min(b[1] for b, _ in rest)
        bx1 = max(b[2] for b, _ in rest); by1 = max(b[3] for b, _ in rest)
        print(f"Many changes: details for the {a.max_regions} largest; {len(rest)} smaller region(s) "
              f"({sum(px for _, px in rest)} px) within x={bx0}..{bx1} y={by0}..{by1}"
              + (f", {outside} of them outside --expect" if expect else ""))
        regions = sorted(by_size[:a.max_regions], key=lambda r: (r[0][1], r[0][0]))

    for i, ((x0, y0, x1, y1), px) in enumerate(regions, 1):
        bx = (max(0, x0 - a.pad), max(0, y0 - a.pad), min(W, x1 + a.pad), min(H, y1 + a.pad))
        ca, cb = im_a.crop(bx), im_b.crop(bx)
        flag = ""
        if expect and not (x0 >= expect[0] and y0 >= expect[1] and x1 <= expect[2] and y1 <= expect[3]):
            flag = "  WARNING: outside --expect"
            outside += 1
        print(f"\n#{i} x={x0}..{x1} y={y0}..{y1} ({x1 - x0}x{y1 - y0}), {px} px changed{flag}")

        # side-by-side crop, enlarged to ~800 px wide if small
        w, h = ca.size
        k = max(1, min(4, 800 // max(1, 2 * w)))
        pair = Image.new("RGB", (2 * w + 6, h), (255, 0, 0))
        pair.paste(ca, (0, 0))
        pair.paste(cb, (w + 6, 0))
        if k > 1:
            pair = pair.resize((pair.width * k, pair.height * k), Image.LANCZOS)
        crop_path = os.path.join(out, f"region_{i}.png")
        pair.save(crop_path)
        print(f"   crop (before | after): {crop_path}")
        # colors of the changed pixels only (the background would otherwise dominate)
        na, nb = np.asarray(ca, dtype=np.int16), np.asarray(cb, dtype=np.int16)
        mask = np.abs(na - nb).max(axis=2) > a.threshold
        print(f"   changed pixels, colors before: {', '.join(main_colors(na[mask]))}")
        print(f"   changed pixels, colors after : {', '.join(main_colors(nb[mask]))}")

        if not a.no_ocr:
            pa, pb = os.path.join(out, f"region_{i}_before.png"), os.path.join(out, f"region_{i}_after.png")
            ca.save(pa)
            cb.save(pb)
            ta, tb = ocr(pa), ocr(pb)
            ra, rb = Counter(ta), Counter(tb)
            for t in (ra - rb).elements():
                print(f"   - {t}")
            for t in (rb - ra).elements():
                print(f"   + {t}")
            if ta == tb and ta:
                print("   text unchanged (change is visual only)")

    if expect:
        print(f"\n{'WARNING: ' + str(outside) + ' region(s) changed outside --expect' if outside else 'All changes are inside --expect.'}")


if __name__ == "__main__":
    main()
