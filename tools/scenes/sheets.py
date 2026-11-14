"""Preview sheets for a scene. Run: python3 sheets.py <value.png> <out_prefix>"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from tint import PALETTES, tint, simulate, to_image, load_value

NAMES = list(PALETTES)


def row(images, gap=12, bg=(251, 250, 246)):
    w = sum(i.width for i in images) + gap * (len(images) + 1)
    h = max(i.height for i in images) + 2 * gap
    s = Image.new("RGB", (w, h), bg)
    x = gap
    for i in images:
        s.paste(i, (x, gap)); x += i.width + gap
    return s


def stack(rows, bg=(251, 250, 246)):
    w = max(r.width for r in rows); h = sum(r.height for r in rows)
    s = Image.new("RGB", (w, h), bg); y = 0
    for r in rows:
        s.paste(r, (0, y)); y += r.height
    return s


def palettes_sheet(value, appearance="paper", scale=2):
    """Five palettes at 2x (700 x 236) in one column."""
    bg = (251, 250, 246) if appearance == "paper" else (20, 18, 15)
    ims = [to_image(tint(value, n, appearance)).resize((350 * scale, 118 * scale), Image.LANCZOS) for n in NAMES]
    return stack([row([i], bg=bg) for i in ims], bg=bg)


def sizes_sheet(value):
    """Each palette at full, half and one-third point size, shown at 2x pixels."""
    rows = []
    for n in NAMES:
        im = to_image(tint(value, n))
        rows.append(row([im.resize((700 // k, 236 // k), Image.LANCZOS) for k in (1, 2, 3)]))
    return stack(rows)


def vision_sheet(value):
    """Rows are palettes. Columns are greyscale, protanopia, deuteranopia, tritanopia."""
    rows = []
    for n in NAMES:
        rgb = np.asarray(to_image(tint(value, n)).resize((350, 118), Image.LANCZOS)).astype(float) / 255
        rows.append(row([to_image(simulate(rgb, k)) for k in ("greyscale", "protanopia", "deuteranopia", "tritanopia")], gap=8))
    return stack(rows)


def save(img, path):
    """Preview sheets are JPEG to keep the repo small. Value layers stay PNG."""
    img.convert("RGB").save(path, quality=88)


if __name__ == "__main__":
    v = load_value(sys.argv[1]); out = sys.argv[2]
    save(palettes_sheet(v), out + "-palettes.jpg")
    save(palettes_sheet(v, "ink"), out + "-palettes-ink.jpg")
    save(sizes_sheet(v), out + "-sizes.jpg")
    save(vision_sheet(v), out + "-vision.jpg")
