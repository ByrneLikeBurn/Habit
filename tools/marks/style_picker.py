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


def tile(style, name, ap, chosen, tw=None, scale=1.0, accent_hex="blue"):
    """One tile. scale is the text scale: 1 at the default size. Above 1.6 the marks drop to their own line and the tile grows."""
    tok = fm.TOK["styles"][style][ap]; paper, text = fm.hexrgb(tok["paper"]), fm.hexrgb(tok["text"]); accent = fm.hexrgb(fm.TOK["swatches"][accent_hex])
    tw = tw or W - 32; big = scale > 1.6
    name_pt, samp_pt, mark_pt = 26 * scale, 17 * scale, 44 * (1.45 if big else 1.0)
    f, feats = display(style, int(name_pt * Q)); kw = {"features": feats} if feats else {}
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    while probe.textlength(name, font=f, **kw) > (tw - 32 - (40 if big else 0)) * Q:           # the name is never cut: it steps down until it fits the tile
        name_pt *= 0.96; f, feats = display(style, int(name_pt * Q))
    f2, _ = display(style, int(samp_pt * Q))
    words, lines, cur = "Walk 10 miles".split(), [], ""
    for w_ in words:
        if cur and probe.textlength(cur + " " + w_, font=f2, **kw) > (tw - 32 - (0 if big else 160)) * Q: lines.append(cur); cur = w_
        else: cur = (cur + " " + w_).strip()
    lines.append(cur)
    k = 1.15 if style == "watercolor" else 1.0
    y_name = 14; y_samp = y_name + name_pt * k * 1.28; y_marks = y_samp + len(lines) * samp_pt * k * 1.3 + 6
    th = int(y_marks + mark_pt + 10) if big else 96
    field = np.ones((th * Q, tw * Q, 3)) * paper
    g = tok.get("grain")
    if g and style != "penAndInk":
        tex = np.resize(fm.tooth if style == "pencil" else fm.dimple, (th * Q, tw * Q))[..., None]
        field = field * (1 - g["maxAlpha"] * tex) + fm.hexrgb(g["color"]) * g["maxAlpha"] * tex
    im = Image.fromarray((np.clip(field, 0, 1) * 255).astype("uint8")); d = ImageDraw.Draw(im)
    d.text((16 * Q, y_name * Q), name, font=f, fill=mix(text, text, 0), **kw)                    # the name is the sample: set in the style's own font
    for i, l in enumerate(lines):                                                                # a habit name with 1, l, i and 0 in it
        d.text((16 * Q, (y_samp + i * samp_pt * k * 1.3) * Q), l, font=f2, fill=mix(paper, text, tok["secondaryAlpha"]), **kw)
    for i, st in enumerate(("done", "part", "paused")):
        if style == "penAndInk": m = ink_mark(st, mix(paper, paper, 0), mix(accent, accent, 0), Q)
        else:
            img, _ = fm.render(style, ap, st, accent); m = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8"))
        side = int(mark_pt * Q); m = m.resize((side, side), Image.LANCZOS)
        if big: im.paste(m, (int((10 + i * (mark_pt + 6)) * Q), int(y_marks * Q)))
        else: im.paste(m, (int((tw - 44 - 3 * 46 + i * 46) * Q), int((th * Q - m.height) / 2)))
    r = 12 * Q
    mask = Image.new("L", im.size, 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=r, fill=255)
    bw = 2 * Q if chosen else Q
    d.rounded_rectangle([bw // 2, bw // 2, im.width - 1 - bw // 2, im.height - 1 - bw // 2], radius=r, outline=mix(text, text, 0) if chosen else mix(paper, text, 0.5), width=bw)   # the unchosen edge holds 3:1
    if chosen:                                                                 # a checkmark in a filled disc, top right: shape, not colour
        s_ = 1.5 if big else 1.0; cx, cy, rr = (tw - 22 * s_) * Q, 22 * s_ * Q, 11 * s_ * Q
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=mix(text, text, 0))
        d.line([(cx - 5 * s_ * Q, cy), (cx - 1.5 * s_ * Q, cy + 3.8 * s_ * Q), (cx + 5.2 * s_ * Q, cy - 4 * s_ * Q)], fill=mix(paper, paper, 0), width=int(2 * s_ * Q), joint="curve")
    return im, mask, th


def page(ap, chosen, width=W, cap=None, scale=1.0):
    """The Appearance page. width is the window's width in points. cap limits the content column, as on the Mac and iPad."""
    base = fm.TOK["styles"]["penAndInk"][ap]; bg, text = fm.hexrgb(base["paper"]), fm.hexrgb(base["text"])
    col = min(width - 32, cap) if cap else width - 32; big = scale > 1.6; ts = min(scale, 2.0)
    im = Image.new("RGB", (width * Q, 2400 * Q), mix(bg, bg, 0)); d = ImageDraw.Draw(im)
    d.text((16 * Q, 20 * Q), "Appearance", font=system(int(28 * min(scale, 1.5) * Q), True), fill=mix(text, text, 0))
    y = 70 if not big else 84
    # the preview: one Today row in the chosen style, on that style's paper
    tok = fm.TOK["styles"][chosen][ap]; pp, pt = fm.hexrgb(tok["paper"]), fm.hexrgb(tok["text"]); accent = fm.hexrgb(fm.TOK["swatches"]["blue"])
    ph = 64 if not big else int(20 * scale * 1.3 + 14 * ts * 1.4 + 76 + 30)
    pv = Image.new("RGB", (col * Q, ph * Q), mix(pp, pp, 0)); pd = ImageDraw.Draw(pv)
    npt = 20 * scale; f, feats = display(chosen, int(npt * Q)); kw = {"features": feats} if feats else {}
    while pd.textlength("Drink water", font=f, **kw) > (col - 32) * Q: npt *= 0.96; f, feats = display(chosen, int(npt * Q))   # never cut. In the app a long name wraps
    pd.text((16 * Q, 9 * Q), "Drink water", font=f, fill=mix(pt, pt, 0), **kw)
    pd.text((16 * Q, (9 + 20 * scale * 1.45) * Q), "3 of 8 glasses", font=system(int(14 * ts * Q)), fill=mix(pp, pt, tok["secondaryAlpha"]))
    img, _ = fm.render(chosen, ap, "part", accent, outline=True); side = int(fm.N / fm.S * Q * (76 / 44 if big else 1))
    ctl = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((side, side), Image.LANCZOS)
    pv.paste(ctl, (10 * Q, pv.height - side - 8 * Q) if big else (pv.width - side - 10 * Q, (pv.height - side) // 2))
    pm = Image.new("L", pv.size, 0); ImageDraw.Draw(pm).rounded_rectangle([0, 0, pv.width - 1, pv.height - 1], radius=12 * Q, fill=255)
    im.paste(pv, (16 * Q, y * Q), pm); y += ph + 16
    d.text((16 * Q, y * Q), "STYLE", font=system(int(13 * ts * Q)), fill=mix(bg, text, base["secondaryAlpha"])); y += int(13 * ts * 1.4) + 6
    for style, name in STYLES:
        t, m, th = tile(style, name, ap, style == chosen, tw=col, scale=scale); im.paste(t, (16 * Q, y * Q), m); y += th + 12
    hf = system(int(13 * ts * Q)); helper = "Changes the look of the whole app."
    words, lines, cur = helper.split(), [], ""
    for w_ in words:
        if cur and d.textlength(cur + " " + w_, font=hf) > col * Q: lines.append(cur); cur = w_
        else: cur = (cur + " " + w_).strip()
    for l in lines + [cur]: d.text((16 * Q, (y - 4) * Q), l, font=hf, fill=mix(bg, text, base["secondaryAlpha"])); y += int(13 * ts * 1.35)
    y += 14
    rf = system(int(17 * ts * Q)); rh = int(46 * (ts if big else 1))
    for label, value in (("Light or dark", "Paper" if ap == "paper" else "Ink"), ("Marks", "Blue")):
        d.line([(16 * Q, y * Q), ((16 + col) * Q, y * Q)], fill=mix(bg, text, base["ruleAlpha"]), width=Q)
        d.text((16 * Q, (y + 13) * Q), label, font=rf, fill=mix(text, text, 0))
        if big: d.text((16 * Q, (y + 13 + 17 * ts * 1.3) * Q), value, font=rf, fill=mix(bg, text, base["secondaryAlpha"])); row = int(rh + 17 * ts * 1.3)
        else:
            vw = d.textlength(value, font=rf); d.text(((16 + col - 18) * Q - vw, (y + 13) * Q), value, font=rf, fill=mix(bg, text, base["secondaryAlpha"])); row = rh
        cx, cy = (16 + col - 4) * Q, (y + row / 2) * Q; d.line([(cx - 3 * Q, cy - 6 * Q), (cx + 3 * Q, cy), (cx - 3 * Q, cy + 6 * Q)], fill=mix(bg, text, base["tertiaryAlpha"]), width=int(1.8 * Q), joint="curve")   # these rows open lists
        y += row
    return im.crop((0, 0, width * Q, (y + 8) * Q))


def sheet(pages, out):
    pad = 40; hh = max(p.height for p in pages)
    sh = Image.new("RGB", (sum(p.width for p in pages) + pad * (len(pages) + 1), hh + 2 * pad), (236, 233, 226)); x = pad
    for p in pages: sh.paste(p, (x, pad)); x += p.width + pad
    sh = sh.resize((sh.width // 2, sh.height // 2), Image.LANCZOS); sh.save(out); print(out, sh.size)


def main(out):
    sheet([page("paper", "pencil"), page("ink", "watercolor")], out)
    sheet([page("paper", "watercolor", scale=3.1), page("ink", "pencil", scale=3.1)], out.replace(".png", "-ax5.png"))      # the largest text size
    sheet([page("paper", "pencil", width=700, cap=360)], out.replace(".png", "-mac.png"))                                  # a wide window: the column stops at 360 points


if __name__ == "__main__": main(sys.argv[1])
