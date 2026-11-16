"""Full-size marks for Pencil and Watercolor, drawn to the rules in docs/spec-m4.md and measured.

    python3 tools/marks/full_marks.py docs/mockups/png/m4-marks.png

Draws every state at 24 points in Paper and Ink, sharp and blurred by 0.75 points, and prints
the contrast of each mark as drawn against the worst pixel of its paper.
"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, distance_transform_edt

S = 10                       # pixels per point
SIZE = 24                    # the mark, in points
PAD = 7                      # room for the today square or ring
N = (SIZE + 2 * PAD) * S     # canvas edge in pixels
C = N / 2
TH = math.radians(56)
TOK = json.load(open("docs/tokens.json"))
rng = np.random.default_rng(7)

def hexrgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255
def lum(c):
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4); return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]
def ratio(a, b): a, b = max(a, b), min(a, b); return (a + 0.05) / (b + 0.05)

def mask(draw_fn):
    im = Image.new("L", (N, N), 0); draw_fn(ImageDraw.Draw(im)); return np.asarray(im, float) / 255
def P(x, y): return (C + x * S, C + y * S)          # points from the centre of the mark, to pixels
def line(d, x0, y0, x1, y1, w): d.line([P(x0, y0), P(x1, y1)], fill=255, width=max(1, round(w * S))); r = w * S / 2; [d.ellipse([px - r, py - r, px + r, py + r], fill=255) for px, py in (P(x0, y0), P(x1, y1))]
def poly(d, pts): d.polygon([P(x, y) for x, y in pts], fill=255)
H = SIZE / 2
SQUARE = [(-H, -H), (H, -H), (H, H), (-H, H)]
LOWER = [(-H, -H), (-H, H), (H, H)]
DIAMOND = [(0, -H), (H, 0), (0, H), (-H, 0)]
CUT = 1.25
tooth = gaussian_filter(rng.random((N, N)), 1.2); tooth = (tooth - tooth.min()) / (tooth.max() - tooth.min())
dimple = gaussian_filter(rng.random((N, N)), 6); dimple = (dimple - dimple.min()) / (dimple.max() - dimple.min())

# ---------- Pencil ----------
def clip_line(px, py, dx, dy, pts):
    """The stretch of the line p + t*d that lies inside a convex polygon, as (t0, t1), or None."""
    t0, t1 = -1e9, 1e9; n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    for i in range(n):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]; ex, ey = bx - ax, by - ay
        sgn = 1 if area > 0 else -1
        num = sgn * (ex * (py - ay) - ey * (px - ax)); den = sgn * (ex * dy - ey * dx)      # inside when num + t*den >= 0
        if abs(den) < 1e-9:
            if num < 0: return None
            continue
        t = -num / den
        if den > 0: t0 = max(t0, t)
        else: t1 = min(t1, t)
    return (t0, t1) if t1 - t0 > 0.4 else None

def pencil_strokes(shapes, n=8, cut=False):
    """Parallel strokes at 56 degrees, each drawn by hand: a little bowed, uneven in length, ends 1 to 2 points past the shape.

    Returns (alpha, core). The core is the solid middle of every stroke, at least 1.5 points wide.
    """
    dx, dy, nx, ny = math.cos(TH), -math.sin(TH), math.sin(TH), math.cos(TH)
    pitch = SIZE * 1.06 / n; w = pitch / 1.5; core_w = max(1.5, w * 0.78)       # the gap is half a stroke, never wider than a stroke
    segs = []
    for k in range(n):
        o = (k - (n - 1) / 2) * pitch + (rng.random() - 0.5) * 0.3; px, py = nx * o, ny * o
        for pts in shapes:
            r = clip_line(px, py, dx, dy, pts)
            if not r: continue
            a, b = r[0] - 1 - rng.random(), r[1] + 1 + rng.random()             # the ends run 1 to 2 points past the shape
            bow = (rng.random() - 0.5) * 0.7; mid = (a + b) / 2
            segs.append([(px + dx * a, py + dy * a), (px + dx * mid + nx * bow, py + dy * mid + ny * bow), (px + dx * b, py + dy * b)])
    def draw(width):
        return mask(lambda d: [line(d, *q[0], *q[1], width) or line(d, *q[1], *q[2], width) for q in segs])
    full, core = draw(w), draw(core_w)
    if cut:
        gap = 1 - mask(lambda d: poly(d, [(-H * 2, -CUT / 2), (H * 2, -CUT / 2), (H * 2, CUT / 2), (-H * 2, CUT / 2)])); full, core = full * gap, core * gap
    edge = np.clip(full - core, 0, 1) * (tooth > 0.42)                          # the tooth erodes the edges only
    return np.clip(core + edge, 0, 1), core

def hand_line(x0, y0, x1, y1, w=1.5):
    j = lambda: (rng.random() - 0.5) * 0.5
    mx, my = (x0 + x1) / 2 + j(), (y0 + y1) / 2 + j()
    return mask(lambda d: line(d, x0 + j(), y0 + j(), mx, my, w) or line(d, mx, my, x1 + j(), y1 + j(), w))

def pencil(state):
    if state == "done": return pencil_strokes([SQUARE])
    if state == "part": return pencil_strokes([LOWER])
    if state == "diamond": return pencil_strokes([[(0, -H), (H, 0), (-H, 0)], [(H, 0), (0, H), (-H, 0)]], cut=True)
    if state == "paused":
        a = math.radians(-10); L = SIZE * 0.34; m = mask(lambda d: line(d, -L * math.cos(a), -L * math.sin(a), L * math.cos(a), L * math.sin(a), 2.4)); return m, m
    if state == "tocome":                                   # short hand-drawn dashes, 1.5 points, gaps of 2 points or more
        m = np.zeros((N, N)); q = H * 0.9
        for (ax, ay), (bx, by) in zip([(-q, -q), (q, -q), (q, q), (-q, q)], [(q, -q), (q, q), (-q, q), (-q, -q)]):
            n = 4
            for i in range(n):
                t0, t1 = (i + 0.12) / n, (i + 0.12) / n + 3.2 / (2 * q)
                m = np.maximum(m, hand_line(ax + (bx - ax) * t0, ay + (by - ay) * t0, ax + (bx - ax) * t1, ay + (by - ay) * t1))
        return m, m
    if state == "notlogged":
        q = H * 0.9; m = np.zeros((N, N))
        for (ax, ay), (bx, by) in zip([(-q, -q), (q, -q), (q, q), (-q, q)], [(q, -q), (q, q), (-q, q), (-q, -q)]): m = np.maximum(m, hand_line(ax, ay, bx, by))
        return m, m
    return np.zeros((N, N)), np.zeros((N, N))

def pencil_today():                                         # four strokes whose ends cross and overshoot each corner by 1 point
    q = H + 4.5; m = np.zeros((N, N))
    for x0, y0, x1, y1 in [(-q - 1, -q, q + 1, -q), (q, -q - 1, q, q + 1), (q + 1, q, -q - 1, q), (-q, q + 1, -q, -q - 1)]: m = np.maximum(m, hand_line(x0, y0, x1, y1, 1.5))
    return m

# ---------- Watercolor ----------
def wobble_shape(pts_fn):
    return mask(lambda d: poly(d, pts_fn()))
def disc_pts(R, amp=0.035):
    ph = rng.random(3) * 6.28
    return [((R * (1 + amp * (math.sin(2 * t + ph[0]) * 0.6 + math.sin(5 * t + ph[1]) * 0.4))) * math.cos(t), (R * (1 + amp * (math.sin(3 * t + ph[2])))) * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 120, endpoint=False)]
def diamond_pts(curve=0.1):
    pts = []; tips = DIAMOND
    for i in range(4):
        (x0, y0), (x1, y1) = tips[i], tips[(i + 1) % 4]; cx, cy = (x0 + x1) / 2 * (1 - 2 * curve), (y0 + y1) / 2 * (1 - 2 * curve)
        for k in range(16):
            u = k / 16; pts.append(((1 - u) ** 2 * x0 + 2 * u * (1 - u) * cx + u * u * x1, (1 - u) ** 2 * y0 + 2 * u * (1 - u) * cy + u * u * y1))
    return pts

def wash(shape, ink):
    """Paper: the rim is 1.5 points at full strength, then falls over 1.75 points with no inner line. The inside is 60% of rim strength or more.
    Ink: opaque paint, flat, no rim, with an edge uneven from the brush."""
    inside = distance_transform_edt(shape > 0.5) / S       # points from the edge
    if ink: return np.clip(inside / 0.6, 0, 1) * (shape > 0.5), (inside > 1.0)
    t = np.clip(1 - (inside - 1.5) / 1.75, 0, 1); rimness = t * t * (3 - 2 * t)      # 1.5 points at full strength, then a soft fall
    alpha = (0.62 + 0.06 * dimple) + (1 - 0.62 - 0.06 * dimple) * rimness
    return alpha * (shape > 0.5), (shape > 0.5) & (inside <= 1.5) & (inside >= 0.3)

def water(state, ink=False):
    R = H
    if state == "done": return wash(wobble_shape(lambda: disc_pts(R)), ink)
    if state == "diamond":
        sh = wobble_shape(diamond_pts) * (1 - mask(lambda d: poly(d, [(-H * 2, -CUT / 2), (H * 2, -CUT / 2), (H * 2, CUT / 2), (-H * 2, CUT / 2)])))
        return wash(sh, ink)
    if state == "part":                                     # three brush strokes at full strength throughout
        dx, dy, nx, ny = math.cos(TH), -math.sin(TH), math.sin(TH), math.cos(TH); w = SIZE * 0.17
        m = mask(lambda d: [line(d, nx * o - dx * L, ny * o - dy * L, nx * o + dx * L, ny * o + dy * L, w) for o, L in ((-SIZE * 0.3, SIZE * 0.26), (0, SIZE * 0.42), (SIZE * 0.3, SIZE * 0.26))])
        return m, m > 0.99
    if state == "paused":
        m = mask(lambda d: line(d, -SIZE * 0.26, 0, SIZE * 0.26, 0, SIZE * 0.17)); return m, m > 0.99
    if state == "tocome":                                   # a ring of short dabs, 1.5 points, gaps of 2 points or more
        r = R * 0.9; n = 12; m = np.zeros((N, N))
        for i in range(n):
            a0 = 2 * math.pi * i / n; a1 = a0 + 2.4 / r
            m = np.maximum(m, mask(lambda d: line(d, r * math.cos(a0), r * math.sin(a0), r * math.cos(a1), r * math.sin(a1), 1.5)))
        return m, m > 0.99
    if state == "notlogged":                                # one thin closed ring at the done mark's size
        o = wobble_shape(lambda: disc_pts(R * 0.98, 0.02)); i = wobble_shape(lambda: disc_pts(R * 0.98 - 1.6, 0.02)); m = np.clip(o - i, 0, 1); return m, m > 0.99
    return np.zeros((N, N)), np.zeros((N, N), bool)

def water_today():                                          # a brushed ring with a visible start and end, gap of 1 point at most
    r = H + 5; m = np.zeros((N, N)); n = 90; gap = 0.9 / r
    for i in range(n):
        a0 = -1.2 + gap + (2 * math.pi - gap) * i / n; a1 = -1.2 + gap + (2 * math.pi - gap) * (i + 1) / n; w = 1.5 + 0.5 * math.sin(i / n * math.pi)
        m = np.maximum(m, mask(lambda d: line(d, r * math.cos(a0), r * math.sin(a0), r * math.cos(a1), r * math.sin(a1), w)))
    return m

# ---------- compose and measure ----------
STATES = [("done", "Done"), ("part", "Part done"), ("paused", "Paused"), ("diamond", "Logged on a paused day or a day off"), ("tocome", "To come"), ("notlogged", "Not logged"), ("today", "Today, done")]

def papers(style, ap):
    t = TOK["styles"][style][ap]; paper = hexrgb(t["paper"]); g = t["grain"]; grain = hexrgb(g["color"])
    worst = paper * (1 - g["maxAlpha"]) + grain * g["maxAlpha"] if ap == "paper" else paper      # the pixel marks contrast least against
    tex = (tooth if style == "pencil" else dimple)[..., None]
    field = paper * (1 - g["maxAlpha"] * tex) + grain * g["maxAlpha"] * tex
    return field, worst, hexrgb(t["text"])

def render(style, ap, state, accent):
    field, worst, text = papers(style, ap); ink = ap == "ink"
    fn = pencil if style == "pencil" else (lambda s: water(s, ink))
    strength = TOK["markAlpha"][style] if not (style == "watercolor" and ink) else 1.0
    if state == "today": a, core = fn("done"); ring = pencil_today() if style == "pencil" else water_today()
    else: a, core = fn(state); ring = None
    a = a * strength
    if style == "pencil" and ink: a = a * np.where((tooth < 0.2) & (core < 0.5), 0.0, 1.0)      # charcoal specks at the edges and between strokes
    img = field * (1 - a[..., None]) + accent * a[..., None]
    if ring is not None: img = img * (1 - ring[..., None]) + text * ring[..., None]
    core = np.asarray(core) > 0.5
    px = accent * strength + worst * (1 - strength) if state not in ("today",) else None
    if core.any():
        drawn = worst * (1 - a[core][:, None]) + accent * a[core][:, None]          # the mark as drawn, over the worst paper pixel
        ls = lum(drawn); lw = float(lum(worst[None])[0]); cr = min(ratio(float(l), lw) for l in (ls.min(), ls.max()))
    else: cr = float("nan")
    return img, cr

def main(out):
    font = ImageFont.load_default(); accent = hexrgb(TOK["swatches"]["blue"])
    cell = N // 2; pad = 14; lab = 170
    rows = [(st, ap) for st in ("pencil", "watercolor") for ap in ("paper", "ink")]
    sheet = Image.new("RGB", (lab + len(STATES) * (2 * cell + pad), 40 + len(rows) * (cell + pad)), (236, 233, 226)); d = ImageDraw.Draw(sheet)
    for ci, (_, name) in enumerate(STATES): d.text((lab + ci * (2 * cell + pad), 8), name[:34], fill=(0, 0, 0), font=font); d.text((lab + ci * (2 * cell + pad), 22), "sharp, blurred 0.75 pt", fill=(90, 90, 90), font=font)
    print(f"{'style':11} {'paper':6} " + " ".join(f"{n[:11]:>11}" for _, n in STATES[:6]))
    for ri, (style, ap) in enumerate(rows):
        y = 40 + ri * (cell + pad); d.text((10, y + cell // 2 - 6), f"{style}, {ap}", fill=(0, 0, 0), font=font); crs = []
        for ci, (st, _) in enumerate(STATES):
            img, cr = render(style, ap, st, accent); crs.append(cr)
            sharp = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((cell, cell), Image.LANCZOS)
            bl = Image.fromarray((np.clip(gaussian_filter(img, sigma=(0.75 * S, 0.75 * S, 0)), 0, 1) * 255).astype("uint8")).resize((cell, cell), Image.LANCZOS)
            x = lab + ci * (2 * cell + pad); sheet.paste(sharp, (x, y)); sheet.paste(bl, (x + cell, y))
        print(f"{style:11} {ap:6} " + " ".join(f"{c:>11.2f}" for c in crs[:6]))
    sheet.save(out); print(sheet.size)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "m4-marks.png")
