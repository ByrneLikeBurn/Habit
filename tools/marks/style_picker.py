"""The style picker on the Appearance page, step 6 of docs/spec-m4.md.

    python3 tools/marks/style_picker.py docs/mockups/png/m4-style-picker.png
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import full_marks as fm

Q = 4; W = 393; F = "docs/mockups/fonts/"
STYLES = [("penAndInk", "Pen and ink"), ("pencil", "Pencil"), ("watercolor", "Watercolor")]


def display(style, size):
    if style == "pencil":
        f = ImageFont.truetype(F + "shantellsans/ShantellSans[BNCE,INFM,SPAC,wght].ttf", size)
        ax = [a["name"] if isinstance(a["name"], str) else a["name"].decode() for a in f.get_variation_axes()]
        f.set_variation_by_axes([{"Weight": 380}.get(n, 0) for n in ax]); return f, ["tnum", "zero"]
    if style == "watercolor": return ImageFont.truetype(F + "alegreyasans/AlegreyaSans-Medium.ttf", int(size * 1.15)), ["lnum", "tnum"]
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", int(size * 0.92)), []      # stand-in for New York
def system(size, bold=False): return ImageFont.truetype(f"/usr/share/fonts/opentype/inter/Inter-{'SemiBold' if bold else 'Regular'}.otf", size)
def mix(a, b, t): return tuple(int(round((a[i] * (1 - t) + b[i] * t) * 255)) for i in range(3))


def ink_mark(state, paper, accent, px):
    """Pen and ink marks at 24 points, as docs/mockups.html draws them."""
    S = 44 * px; im = Image.new("RGB", (S, S), paper); d = ImageDraw.Draw(im); c = S / 2; a = 24 * 0.78 * px; x0 = c - a / 2; sw = int(1.5 * px)
    box = [x0, x0, x0 + a, x0 + a]
    if state == "done": d.rounded_rectangle(box, radius=a * 0.07, fill=accent)
    if state == "part":
        clip = Image.new("L", (S, S), 0); ImageDraw.Draw(clip).rounded_rectangle(box, radius=a * 0.07, fill=255)
        lay = Image.new("RGB", (S, S), paper); ld = ImageDraw.Draw(lay); t = math.tan(math.radians(56))
        for k in range(-8, 9):
            xb = c + k * 5 * px; ld.line([(xb - a / t, c + a), (xb + a / t, c - a)], fill=accent, width=sw)
        im.paste(lay, (0, 0), clip); d.rounded_rectangle(box, radius=a * 0.07, outline=accent, width=sw)
    if state == "paused": d.line([(c - a * 0.3, c), (c + a * 0.3, c)], fill=accent, width=sw + px); [d.ellipse([x - (sw + px) / 2, c - (sw + px) / 2, x + (sw + px) / 2, c + (sw + px) / 2], fill=accent) for x in (c - a * 0.3, c + a * 0.3)]
    return im


def tile(style, name, ap, chosen, accent_hex="blue"):
    tok = fm.TOK["styles"][style][ap]; paper, text = fm.hexrgb(tok["paper"]), fm.hexrgb(tok["text"]); accent = fm.hexrgb(fm.TOK["swatches"][accent_hex])
    tw, th = W - 32, 96
    field = np.ones((th * Q, tw * Q, 3)) * paper
    g = tok.get("grain")
    if g and style != "penAndInk":
        tex = np.resize(fm.tooth if style == "pencil" else fm.dimple, (th * Q, tw * Q))[..., None]
        field = field * (1 - g["maxAlpha"] * tex) + fm.hexrgb(g["color"]) * g["maxAlpha"] * tex
    im = Image.fromarray((np.clip(field, 0, 1) * 255).astype("uint8")); d = ImageDraw.Draw(im)
    f, feats = display(style, 26 * Q); kw = {"features": feats} if feats else {}
    d.text((16 * Q, 14 * Q), name, font=f, fill=mix(text, text, 0), **kw)                       # the name is the sample: set in the style's own font
    f2, _ = display(style, 17 * Q)
    d.text((16 * Q, 58 * Q), "Walk 10 miles", font=f2, fill=mix(paper, text, tok["secondaryAlpha"]), **kw)   # a habit name with 1, l, i and 0 in it
    for i, st in enumerate(("done", "part", "paused")):
        if style == "penAndInk": m = ink_mark(st, mix(paper, paper, 0), mix(accent, accent, 0), Q)
        else:
            img, _ = fm.render(style, ap, st, accent); side = int(fm.N / fm.S * Q)
            m = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((side, side), Image.LANCZOS)
        im.paste(m, (int((tw - 44 - 3 * 46 + i * 46) * Q), int((th * Q - m.height) / 2)))
    r = 12 * Q
    mask = Image.new("L", im.size, 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=r, fill=255)
    bw = 2 * Q if chosen else Q
    d.rounded_rectangle([bw // 2, bw // 2, im.width - 1 - bw // 2, im.height - 1 - bw // 2], radius=r, outline=mix(text, text, 0) if chosen else mix(paper, text, 0.5), width=bw)   # the unchosen edge holds 3:1
    if chosen:                                                                 # a checkmark in a filled disc, top right: shape, not colour
        cx, cy, rr = (tw - 22) * Q, 22 * Q, 11 * Q
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=mix(text, text, 0))
        d.line([(cx - 5 * Q, cy), (cx - 1.5 * Q, cy + 3.8 * Q), (cx + 5.2 * Q, cy - 4 * Q)], fill=mix(paper, paper, 0), width=int(2 * Q), joint="curve")
    return im, mask


def page(ap, chosen):
    base = fm.TOK["styles"]["penAndInk"][ap]; bg, text = fm.hexrgb(base["paper"]), fm.hexrgb(base["text"])
    im = Image.new("RGB", (W * Q, 660 * Q), mix(bg, bg, 0)); d = ImageDraw.Draw(im)
    d.text((16 * Q, 20 * Q), "Appearance", font=system(28 * Q, True), fill=mix(text, text, 0))
    # the preview: one Today row in the chosen style, on that style's paper
    tok = fm.TOK["styles"][chosen][ap]; pp, pt = fm.hexrgb(tok["paper"]), fm.hexrgb(tok["text"]); accent = fm.hexrgb(fm.TOK["swatches"]["blue"])
    pv = Image.new("RGB", ((W - 32) * Q, 64 * Q), mix(pp, pp, 0)); pd = ImageDraw.Draw(pv)
    f, feats = display(chosen, 20 * Q); kw = {"features": feats} if feats else {}
    pd.text((16 * Q, 9 * Q), "Drink water", font=f, fill=mix(pt, pt, 0), **kw)
    pd.text((16 * Q, 38 * Q), "3 of 8 glasses", font=system(14 * Q), fill=mix(pp, pt, tok["secondaryAlpha"]))
    img, _ = fm.render(chosen, ap, "part", accent, outline=True); side = int(fm.N / fm.S * Q)
    pv.paste(Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((side, side), Image.LANCZOS), (pv.width - side - 10 * Q, (pv.height - side) // 2))
    pm = Image.new("L", pv.size, 0); ImageDraw.Draw(pm).rounded_rectangle([0, 0, pv.width - 1, pv.height - 1], radius=12 * Q, fill=255)
    im.paste(pv, (16 * Q, 70 * Q), pm)
    d.text((16 * Q, 150 * Q), "STYLE", font=system(13 * Q), fill=mix(bg, text, base["secondaryAlpha"]))
    y = 174
    for style, name in STYLES:
        t, m = tile(style, name, ap, style == chosen); im.paste(t, (16 * Q, y * Q), m); y += 96 + 12
    d.text((16 * Q, (y - 4) * Q), "Changes the look of the whole app.", font=system(13 * Q), fill=mix(bg, text, base["secondaryAlpha"])); y += 30
    for label, value in (("Light or dark", "Paper" if ap == "paper" else "Ink"), ("Marks", "Blue")):
        d.line([(16 * Q, y * Q), ((W - 16) * Q, y * Q)], fill=mix(bg, text, base["ruleAlpha"]), width=Q)
        d.text((16 * Q, (y + 13) * Q), label, font=system(17 * Q), fill=mix(text, text, 0))
        vw = d.textlength(value, font=system(17 * Q)); d.text(((W - 34) * Q - vw, (y + 13) * Q), value, font=system(17 * Q), fill=mix(bg, text, base["secondaryAlpha"]))
        cx, cy = (W - 20) * Q, (y + 23) * Q; d.line([(cx - 3 * Q, cy - 6 * Q), (cx + 3 * Q, cy), (cx - 3 * Q, cy + 6 * Q)], fill=mix(bg, text, base["tertiaryAlpha"]), width=int(1.8 * Q), joint="curve")   # these rows open lists
        y += 46
    return im.crop((0, 0, W * Q, (y + 8) * Q))


def main(out):
    ps = [page("paper", "pencil"), page("ink", "watercolor")]; pad = 40
    sheet = Image.new("RGB", (sum(p.width for p in ps) + pad * 3, ps[0].height + 2 * pad), (236, 233, 226)); x = pad
    for p in ps: sheet.paste(p, (x, pad)); x += p.width + pad
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS); sheet.save(out); print(sheet.size)


if __name__ == "__main__": main(sys.argv[1])
