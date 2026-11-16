"""Small mark shapes for each style, with the blur test from docs/spec-m4.md.

Draws every state at 6 and 12 points in a 12-unit cell, sharp and blurred, and
prints how far apart each pair of states is after a Gaussian blur of one eighth
of the mark's width, in greyscale.

    python3 tools/marks/small_shapes.py docs/mockups/png/m4-small-shapes.png
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter

S = 20                      # pixels per unit; a cell is 12 units
CELL = 12 * S
LEAN = 9 / math.tan(math.radians(56))   # sideways run of a 56 degree edge over 9 units

def canvas():
    im = Image.new("L", (CELL, CELL), 0)
    return im, ImageDraw.Draw(im)

def poly(pts):
    im, d = canvas(); d.polygon([(x * S, y * S) for x, y in pts], fill=255); return im

def bar_thickness(size):    # at least 2 points, in units of a 12-unit cell
    return max(2.5, 2 * 12 / size)

def dot(size):
    im, d = canvas(); r = 1.5
    d.ellipse([(6 - r) * S, (6 - r) * S, (6 + r) * S, (6 + r) * S], fill=255); return im

def pen(state, size):
    if state == "done": return poly([(1, 1), (11, 1), (11, 11), (1, 11)])
    if state == "part": return poly([(1, 1), (1, 11), (11, 11)])
    if state == "paused":
        t = bar_thickness(size) / 2; return poly([(1, 6 - t), (11, 6 - t), (11, 6 + t), (1, 6 + t)])
    if state == "diamond": return poly([(6, 0), (12, 6), (6, 12), (0, 6)])
    return dot(size)

def pencil(state, size):
    b = 12 - LEAN           # base of the leaning block
    if state == "done": return poly([(0, 10.5), (b, 10.5), (12, 1.5), (12 - b, 1.5)])
    if state == "part": return poly([(0, 10.5), (b, 10.5), (12, 1.5)])
    if state == "paused":
        t = bar_thickness(size) / 2; a = math.radians(-10); c, s = math.cos(a), math.sin(a)
        pts = [(-5, 0), (-3.5, -t), (3.5, -t), (5, 0), (3.5, t), (-3.5, t)]     # tapered ends
        return poly([(6 + x * c - y * s, 6 + x * s + y * c) for x, y in pts])
    if state == "diamond":
        dx = 6 / math.tan(math.radians(56)); return poly([(6 + dx, 0), (12, 6), (6 - dx, 12), (0, 6)])
    return dot(size)

def water(state, size, curved=False):
    im, d = canvas()
    if state == "done": d.ellipse([1.5 * S, 1.5 * S, 10.5 * S, 10.5 * S], fill=255); return im
    if state == "part": d.pieslice([1.5 * S, 1.5 * S, 10.5 * S, 10.5 * S], 90, 270, fill=255); return im
    if state == "paused":
        t = bar_thickness(size) / 2
        d.rounded_rectangle([1.5 * S, (6 - t) * S, 10.5 * S, (6 + t) * S], radius=t * S, fill=255); return im
    if state == "diamond":
        if not curved: return poly([(6, 0), (12, 6), (6, 12), (0, 6)])
        pts = []; tips = [(6, 0), (12, 6), (6, 12), (0, 6)]
        for i in range(4):                       # sides that curve inward
            (x0, y0), (x1, y1) = tips[i], tips[(i + 1) % 4]
            cx, cy = 6 + (x0 + x1 - 12) * 0.28, 6 + (y0 + y1 - 12) * 0.28
            for k in range(24):
                u = k / 24; pts.append(((1-u)**2*x0 + 2*u*(1-u)*cx + u*u*x1, (1-u)**2*y0 + 2*u*(1-u)*cy + u*u*y1))
        return poly(pts)
    return dot(size)

STYLES = [("Pen and ink", pen), ("Pencil", pencil), ("Watercolor", lambda s, z: water(s, z)), ("Watercolor, curved", lambda s, z: water(s, z, True))]
STATES = ["done", "part", "paused", "diamond", "dot"]
PAIRS = [("done", "part"), ("done", "diamond"), ("paused", "dot"), ("part", "paused"), ("part", "dot"), ("diamond", "paused")]

def blurred(im):            # one eighth of the mark's width
    return gaussian_filter(np.asarray(im, float) / 255, sigma=CELL / 8)

def apart(a, b):            # 0 means the same blur, 1 means no overlap
    return float(np.abs(a - b).sum() / (a.sum() + b.sum()))

def main(out):
    font = ImageFont.load_default()
    pad, lab = 16, 150
    cols = [(name, fn, size) for name, fn in STYLES for size in (12, 6)]
    W = lab + len(cols) * (2 * CELL // 2 + pad) + pad
    H = 60 + len(STATES) * (CELL // 2 + pad)
    sheet = Image.new("L", (W, H), 255); d = ImageDraw.Draw(sheet)
    for ci, (name, fn, size) in enumerate(cols):
        x = lab + ci * (CELL + pad)
        d.text((x, 10), f"{name}", fill=0, font=font); d.text((x, 26), f"{size} pt: sharp, blurred", fill=0, font=font)
        for si, st in enumerate(STATES):
            y = 60 + si * (CELL // 2 + pad)
            im = fn(st, size); half = CELL // 2
            sharp = Image.eval(im.resize((half, half), Image.LANCZOS), lambda v: 255 - v)
            bl = Image.fromarray((255 - blurred(im) * 255).astype("uint8")).resize((half, half), Image.LANCZOS)
            sheet.paste(sharp, (x, y)); sheet.paste(bl, (x + half, y))
    for si, st in enumerate(STATES):
        d.text((10, 60 + si * (CELL // 2 + pad) + 50), st, fill=0, font=font)
    sheet.save(out)
    print("How far apart two states are after the blur. 0 is identical, 1 is no overlap.\n")
    print(f"{'style':20} {'size':>4}  " + "  ".join(f"{a[:4]}/{b[:4]:<7}" for a, b in PAIRS))
    for name, fn, size in cols:
        B = {st: blurred(fn(st, size)) for st in STATES}
        print(f"{name:20} {size:>4}  " + "  ".join(f"{apart(B[a], B[b]):<12.2f}" for a, b in PAIRS))
    print("\nThe same state across styles, at 6 points:")
    for st in STATES[:4]:
        B = {name: blurred(fn(st, 6)) for name, fn in STYLES[:3]}
        print(f"  {st:8} pen/pencil {apart(B['Pen and ink'], B['Pencil']):.2f}   pen/water {apart(B['Pen and ink'], B['Watercolor']):.2f}   pencil/water {apart(B['Pencil'], B['Watercolor']):.2f}")
    a, b = blurred(water("diamond", 6)), blurred(water("diamond", 6, True)); disc = blurred(water("done", 6))
    print(f"\nWatercolor diamond against the disc, 6 points: straight {apart(a, disc):.2f}, curved {apart(b, disc):.2f}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "small-shapes.png")
