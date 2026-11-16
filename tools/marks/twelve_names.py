"""Step 5 gate in docs/spec-m4.md: twelve habit names at 17 points in each style's display font, beside the system font.

    python3 tools/marks/twelve_names.py docs/mockups/png/m4-twelve-names.png
"""
import json, sys
from PIL import Image, ImageDraw, ImageFont, features

Q = 3                                    # pixels per point
TOK = json.load(open("docs/tokens.json"))
F = "docs/mockups/fonts/"
NAMES = ["Drink water", "Read 10 pages", "Walk outside", "Take vitamins", "Stretch before bed", "Call Illia or Lil",
         "Practise the cello piece for the spring concert", "No phone after 10:30", "Tidy one shelf", "Journal", "Water the plants", "Play: 1 round of Go"]
RAQM = features.check("raqm")

def font(kind, size):
    if kind == "pencil":
        f = ImageFont.truetype(F + "shantellsans/ShantellSans[BNCE,INFM,SPAC,wght].ttf", size)
        ax = [a["name"] if isinstance(a["name"], str) else a["name"].decode() for a in f.get_variation_axes()]
        f.set_variation_by_axes([{"Weight": 380}.get(n, 0) for n in ax]); return f, ["tnum", "zero"]
    if kind == "watercolor": return ImageFont.truetype(F + "alegreyasans/AlegreyaSans-Medium.ttf", size), ["lnum", "tnum"]
    return ImageFont.truetype("/usr/share/fonts/opentype/inter/Inter-Regular.otf", size), []

def hexrgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def panel(style, kind, ap, title):
    t = TOK["styles"][style][ap]; paper, text = hexrgb(t["paper"]), hexrgb(t["text"])
    W, row = 300, 48; im = Image.new("RGB", (W * Q, (40 + row * len(NAMES) + 12) * Q), paper); d = ImageDraw.Draw(im)
    lab, _ = font("system", 11 * Q); d.text((16 * Q, 12 * Q), title, font=lab, fill=tuple((p + x) // 2 for p, x in zip(paper, text)))
    size, track, wordx = (19.5, 0.02, 1.25) if kind == "watercolor" else (17, 0, 1)      # Alegreya's lowercase is small: 19.5 points matches the system font's at 17
    f, feats = font(kind, round(size * Q)); kw = {"features": feats} if RAQM and feats else {}
    def length(t): return sum(f.getlength(w, **kw) + len(w) * track * size * Q for w in t.split()) + (len(t.split()) - 1) * f.getlength(" ") * wordx
    def draw(x, y, t):
        for w in t.split():
            for i, ch in enumerate(w): d.text((x + f.getlength(w[:i], **kw) + i * track * size * Q, y), ch, font=f, fill=text, **kw)
            x += f.getlength(w, **kw) + len(w) * track * size * Q + f.getlength(" ") * wordx
    for i, n in enumerate(NAMES):
        words, lines, cur = n.split(), [], ""
        for w in words:
            if cur and length(cur + " " + w) > (W - 32) * Q: lines.append(cur); cur = w
            else: cur = (cur + " " + w).strip()
        lines.append(cur); lh = size * 1.25; y = 40 + i * row + (row - len(lines) * lh) / 2
        for k, l in enumerate(lines): draw(16 * Q, (y + k * lh) * Q, l)
    return im

def main(out):
    ps = [panel(s, k, ap, f"{lbl}, {ap}") for s, k, lbl in (("pencil", "pencil", "Pencil: Shantell Sans 380"), ("pencil", "system", "Pencil paper, system font"), ("watercolor", "watercolor", "Watercolor: Alegreya Sans Medium 19.5"), ("watercolor", "system", "Watercolor paper, system font")) for ap in ("paper", "ink")]
    pad = 24; sheet = Image.new("RGB", (sum(p.width for p in ps) + pad * (len(ps) + 1), ps[0].height + 2 * pad), (236, 233, 226)); x = pad
    for p in ps: sheet.paste(p, (x, pad)); x += p.width + pad
    sheet.save(out); print(sheet.size, "font features applied:", RAQM)

if __name__ == "__main__": main(sys.argv[1])
