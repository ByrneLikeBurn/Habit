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
        ("Take vitamins", "Paused", "paused"), ("Stretch before bed", "Logged while paused", "diamond"),
        ("Practise the cello piece for the spring concert", "10 of 20 minutes", "part")]
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
    gap = 0 if style == "pencil" else name_line - line_gap               # Watercolor: one line of the name more between rows, with no rule
    nf, lf = display(style, name_size * Q), label(14 * Q); maxw = (W - 21 - 44 - 21 - 12) * Q
    def wrap(t):
        out, cur = [], ""
        for w in t.split():
            if cur and nf.getlength(cur + " " + w) > maxw: out.append(cur); cur = w
            else: cur = (cur + " " + w).strip()
        return out + [cur]
    lines = [wrap(n) for n, _, _ in ROWS]
    hs = [max(58, 16 + len(l) * name_line + (19 if sub else 0)) + gap for l, (_, sub, _) in zip(lines, ROWS)]
    H = int((96 + sum(hs) + 24) * Q)
    field = np.ones((H, W * Q, 3)) * paper
    g = tok["grain"]; tex = np.resize(fm.tooth if style == "pencil" else fm.dimple, (H, W * Q))[..., None]
    field = field * (1 - g["maxAlpha"] * tex) + fm.hexrgb(g["color"]) * g["maxAlpha"] * tex
    rng = np.random.default_rng(3); y = 96
    if style == "pencil":                                                    # one pencil stroke between rows: bow of 1 point at most, inset 2 to 4 points, pressure varies, the tooth breaks it
        big = np.resize(fm.tooth, (H, W * Q)); yy = 96
        for i, h in enumerate(hs[:-1]):
            yy += h; x0, x1 = 21 + 2 + rng.random() * 2, W - 21 - 2 - rng.random() * 2; bow = (rng.random() - 0.5) * 2; ph = rng.random(2) * 6.28
            for px in range(int(x0 * Q), int(x1 * Q)):
                t = (px / Q - x0) / (x1 - x0); cyp = (yy + bow * math.sin(math.pi * t)) * Q
                press = (0.62 + 0.2 * math.sin(t * 5 + ph[0]) + 0.12 * math.sin(t * 17 + ph[1])) * min(1, t / 0.03 + 0.4, (1 - t) / 0.03 + 0.4)
                for py in range(int(cyp - Q), int(cyp + Q) + 1):
                    a = max(0, 1 - abs(py - cyp) / (Q * 0.55)) * press * (0.25 if big[py, px] > 0.6 else 1)
                    field[py, px] = field[py, px] * (1 - a) + text * a
    im = Image.fromarray((np.clip(field, 0, 1) * 255).astype("uint8")); d = ImageDraw.Draw(im)
    tcol, sec = mix(text, text, 0), mix(paper, text, tok["secondaryAlpha"])
    d.text((21 * Q, 24 * Q), "Today", font=display(style, 34 * Q), fill=tcol)
    d.text((21 * Q, 68 * Q), "Saturday 14 November", font=label(15 * Q), fill=sec)
    for (name, sub, state), ls, h in zip(ROWS, lines, hs):
        cy = y + h / 2; block = len(ls) * name_line + (19 if sub else 0); ty = cy - block / 2
        for k, l in enumerate(ls): d.text((21 * Q, (ty + k * name_line) * Q), l, font=nf, fill=tcol)
        if sub: d.text((21 * Q, (ty + len(ls) * name_line + 1) * Q), sub, font=lf, fill=sec)
        img, _ = fm.render(style, ap, state, accent, outline=True)           # the control: the mark inside the today square or ring
        side = int(fm.N / fm.S * Q); ctl = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((side, side), Image.LANCZOS)
        im.paste(ctl, (int((W - 21 - 44) * Q + (44 * Q - side) / 2), int(cy * Q - side / 2)))
        y += h
    return im

def main(out):
    panels = [panel(s, a) for s in ("pencil", "watercolor") for a in ("paper", "ink")]
    pad = 40; Hh = max(p.height for p in panels)
    sheet = Image.new("RGB", (sum(p.width for p in panels) + pad * (len(panels) + 1), Hh + 2 * pad), (236, 233, 226)); x = pad
    for p in panels: sheet.paste(p, (x, pad)); x += p.width + pad
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS); sheet.save(out); print(sheet.size)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "m4-today-rows.png")
