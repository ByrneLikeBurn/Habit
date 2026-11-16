"""Today rows in Pencil and Watercolor, drawn to step 3 of docs/spec-m4.md.

    python3 tools/marks/today_rows.py docs/mockups/png/m4-today-rows.png
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import full_marks as fm

Q = 4                                   # pixels per point in the row drawing
W = 393                                 # a phone's width in points
ROWS = [("Drink water", "3 of 8 glasses", "part"), ("Read", "", "done"), ("Walk outside", "", "blank"),
        ("Take vitamins", "Paused", "paused"), ("Stretch before bed", "Logged while paused", "diamond")]
F = "docs/mockups/fonts/"

def display(style, size):
    if style == "pencil":
        f = ImageFont.truetype(F + "shantellsans/ShantellSans[BNCE,INFM,SPAC,wght].ttf", size)
        axes = [a["name"] if isinstance(a["name"], str) else a["name"].decode() for a in f.get_variation_axes()]
        vals = {"Weight": 400}
        f.set_variation_by_axes([vals.get(n, 0) for n in axes]); return f
    return ImageFont.truetype(F + "alegreyasans/AlegreyaSans-Medium.ttf", size)
def label(size): return ImageFont.truetype("/usr/share/fonts/opentype/inter/Inter-Regular.otf", size)

def mix(a, b, t): return tuple(int(round((a[i] * (1 - t) + b[i] * t) * 255)) for i in range(3))

def panel(style, ap):
    tok = fm.TOK["styles"][style][ap]; paper, text = fm.hexrgb(tok["paper"]), fm.hexrgb(tok["text"])
    accent = fm.hexrgb(fm.TOK["swatches"]["blue"])
    line_gap = 6; name_size = 20; name_line = name_size * 1.25
    row_h = 58 if style == "pencil" else 58 + name_line - line_gap          # Watercolor: one line of the name more, with no rule
    H = int((96 + row_h * len(ROWS) + 24) * Q)
    field = np.ones((H, W * Q, 3)) * paper
    g = tok["grain"]; tex = np.resize(fm.tooth if style == "pencil" else fm.dimple, (H, W * Q))[..., None]
    field = field * (1 - g["maxAlpha"] * tex) + fm.hexrgb(g["color"]) * g["maxAlpha"] * tex
    im = Image.fromarray((np.clip(field, 0, 1) * 255).astype("uint8")); d = ImageDraw.Draw(im)
    tcol, sec, ter = mix(text, text, 0), mix(paper, text, tok["secondaryAlpha"]), mix(paper, text, tok["tertiaryAlpha"])
    d.text((21 * Q, 24 * Q), "Today", font=display(style, 34 * Q), fill=tcol)
    d.text((21 * Q, 68 * Q), "Saturday 14 November", font=label(15 * Q), fill=sec)
    rng = np.random.default_rng(3)
    for i, (name, sub, state) in enumerate(ROWS):
        y = 96 + i * row_h; cy = y + row_h / 2
        if style == "pencil" and i > 0:                                      # one pencil stroke, bowed by at most 1 point, inset 2 to 4 points
            x0, x1 = 21 + 2 + rng.random() * 2, W - 21 - 2 - rng.random() * 2; bow = (rng.random() - 0.5) * 2
            pts = [((x0 + (x1 - x0) * t) * Q, (y + bow * math.sin(math.pi * t)) * Q) for t in np.linspace(0, 1, 40)]
            d.line(pts, fill=mix(paper, text, tok["ruleAlpha"] + 0.1), width=Q)
        ty = cy - (name_line / 2 if not sub else name_line / 2 + 9)
        d.text((21 * Q, ty * Q), name, font=display(style, name_size * Q), fill=tcol)
        if sub: d.text((21 * Q, (ty + name_line + 1) * Q), sub, font=label(14 * Q), fill=sec)
        img, _ = fm.render(style, ap, state, accent, outline=True)           # the control: the mark inside the today square or ring
        side = int(fm.N / fm.S * Q); ctl = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((side, side), Image.LANCZOS)
        im.paste(ctl, (int((W - 21 - 44) * Q + (44 * Q - side) / 2), int(cy * Q - side / 2)))
    return im

def main(out):
    panels = [panel(s, a) for s in ("pencil", "watercolor") for a in ("paper", "ink")]
    pad = 40; Hh = max(p.height for p in panels)
    sheet = Image.new("RGB", (sum(p.width for p in panels) + pad * (len(panels) + 1), Hh + 2 * pad), (236, 233, 226)); x = pad
    for p in panels: sheet.paste(p, (x, pad)); x += p.width + pad
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS); sheet.save(out); print(sheet.size)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "m4-today-rows.png")
