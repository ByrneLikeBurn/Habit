"""Full-size marks for Pencil and Watercolor, drawn to the rules in docs/spec-m4.md and measured.

    python3 tools/marks/full_marks.py docs/mockups/png/m4-marks.png

Draws every state at 24 points in Paper and Ink, sharp and blurred by 0.75 points, and prints
the contrast of each mark as drawn against the worst pixel of its paper.
"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, maximum_filter, distance_transform_edt

S = 10                       # pixels per point
SIZE = 24                    # the mark, in points
PAD = 10                     # room for the today square or ring
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
def stamp(d, pts, width_at, steps=60):
    """A stroke along a three-point path. width_at(t) gives its width in points, t from 0 to 1."""
    (x0, y0), (x1, y1), (x2, y2) = pts
    for i in range(steps + 1):
        t = i / steps; x = (1 - t) ** 2 * x0 + 2 * t * (1 - t) * x1 + t * t * x2; y = (1 - t) ** 2 * y0 + 2 * t * (1 - t) * y1 + t * t * y2
        r = width_at(t) * S / 2; px, py = P(x, y); d.ellipse([px - r, py - r, px + r, py + r], fill=255)
def bowed(x0, y0, x1, y1, bow):
    nx, ny = -(y1 - y0), x1 - x0; L = math.hypot(nx, ny) or 1
    return [(x0, y0), ((x0 + x1) / 2 + nx / L * bow * 2, (y0 + y1) / 2 + ny / L * bow * 2), (x1, y1)]
def taper(w, lo=0.45, run=0.14):          # a pencil stroke: thin where it lands and where it lifts
    return lambda t: w * (lo + (1 - lo) * min(1, t / run, (1 - t) / run) ** 0.7)
def brush(w):                              # a brush stroke: pooled where it starts, lifted where it ends
    return lambda t: w * (1.12 - 0.12 * min(1, t / 0.2)) * (1 if t < 0.72 else 1 - 0.5 * ((t - 0.72) / 0.28) ** 1.5)
def poly(d, pts): d.polygon([P(x, y) for x, y in pts], fill=255)
H = SIZE / 2
SQUARE = [(-H, -H), (H, -H), (H, H), (-H, H)]
LOWER = [(-H, -H), (-H, H), (H, H)]
DIAMOND = [(0, -H), (H, 0), (0, H), (-H, 0)]
CUT = 1.25
GROW = 0.0                   # Increase Contrast: the today square is half a point larger and the ring 0.6, so the heavier strokes keep 3 points clear
GAPX = 0.0                   # Increase Contrast: extra space between the dashes of 'to come', so 2 points of paper remain after the strokes thicken
AMP = 0.035                  # how uneven the Watercolor disc's edge is
tooth = gaussian_filter(rng.random((N, N)), 1.2); tooth = (tooth - tooth.min()) / (tooth.max() - tooth.min())
speck = gaussian_filter(rng.random((N, N)), 2.6); speck = (speck - speck.min()) / (speck.max() - speck.min())   # charcoal specks, about half a point across
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

def pencil_strokes(shapes, n=11, cut=False):
    """Parallel strokes at 56 degrees, each drawn by hand: a little bowed, uneven in length, ends 1 to 2 points past the shape.

    Returns (alpha, core). The core is the solid middle of every stroke, at least 1.5 points wide.
    """
    dx, dy, nx, ny = math.cos(TH), -math.sin(TH), math.sin(TH), math.cos(TH)
    pitch = SIZE * 1.04 / n; w = pitch + 0.25; core_w = max(1.5, w * 0.8)       # strokes overlap a little, so no gap opens between two of them, so done blurs to a solid; the eroded edges still show each stroke
    segs = []
    for k in range(n):
        o = (k - (n - 1) / 2) * pitch + (rng.random() - 0.5) * 0.12; px, py = nx * o, ny * o
        for pts in shapes:
            r = clip_line(px, py, dx, dy, pts)
            if not r: continue
            a, b = r[0] - 1 - rng.random(), r[1] + 1 + rng.random()             # the ends run 1 to 2 points past the shape
            bow = (rng.random() - 0.5) * 0.7; mid = (a + b) / 2
            segs.append(([(px + dx * a, py + dy * a), (px + dx * mid + nx * bow, py + dy * mid + ny * bow), (px + dx * b, py + dy * b)], 0.92 + rng.random() * 0.16))
    def draw(width):
        return mask(lambda d: [stamp(d, q, taper(width * press)) for q, press in segs])
    full, core = draw(w), draw(core_w)
    if cut:
        gap = 1 - mask(lambda d: poly(d, [(-H * 2, -CUT / 2), (H * 2, -CUT / 2), (H * 2, CUT / 2), (-H * 2, CUT / 2)])); full, core = full * gap, core * gap
    edge = np.clip(full - core, 0, 1) * (tooth > 0.26)                          # the tooth erodes the edges only
    return np.clip(core + edge, 0, 1), core

def hand_line(x0, y0, x1, y1, w=1.5):
    j = lambda: (rng.random() - 0.5) * 0.5
    return mask(lambda d: stamp(d, bowed(x0 + j(), y0 + j(), x1 + j(), y1 + j(), (rng.random() - 0.5) * 0.5), taper(w, 0.7, 0.08)))

def pencil(state):
    if state == "done": return pencil_strokes([SQUARE])
    if state == "part": return pencil_strokes([LOWER])
    if state == "diamond": return pencil_strokes([[(0, -H), (H, 0), (-H, 0)], [(H, 0), (0, H), (-H, 0)]], cut=True)
    if state == "paused":
        a = math.radians(-10); L = SIZE * 0.34; m = mask(lambda d: stamp(d, bowed(-L * math.cos(a), -L * math.sin(a), L * math.cos(a), L * math.sin(a), 0.25), taper(2.6, 0.6, 0.1))); return m, m
    if state == "tocome":                                   # short hand-drawn dashes of uneven length, 2 points, gaps of 2 points or more
        m = np.zeros((N, N)); q = H * 0.9
        for (ax, ay), (bx, by) in zip([(-q, -q), (q, -q), (q, q), (-q, q)], [(q, -q), (q, q), (-q, q), (-q, -q)]):
            t = 0.04
            while t < 0.9:
                ln = (2.6 + rng.random() * 1.8) / (2 * q); t1 = min(t + ln, 0.98)
                m = np.maximum(m, hand_line(ax + (bx - ax) * t, ay + (by - ay) * t, ax + (bx - ax) * t1, ay + (by - ay) * t1, 2.0)); t = t1 + (2.2 + rng.random() * 0.8 + GAPX) / (2 * q)
        return m, m
    if state == "notlogged":
        q = H * 0.9; m = np.zeros((N, N))
        for (ax, ay), (bx, by) in zip([(-q, -q), (q, -q), (q, q), (-q, q)], [(q, -q), (q, q), (-q, q), (-q, -q)]): m = np.maximum(m, mask(lambda d: stamp(d, bowed(ax - (bx - ax) * 0.04, ay - (by - ay) * 0.04 + (rng.random() - 0.5) * 0.6, bx + (bx - ax) * 0.04, by + (by - ay) * 0.04 + (rng.random() - 0.5) * 0.6, (1.1 + rng.random() * 0.7) * (1 if rng.random() < 0.5 else -1)), taper(1.9, 0.6, 0.1))))
        return m, m
    return np.zeros((N, N)), np.zeros((N, N))

def pencil_today():                                         # four strokes whose ends cross and overshoot each corner by 1 point
    q = H + 7 + GROW; m = np.zeros((N, N))      # 3 points clear of the mark, stroke ends and bow included
    for x0, y0, x1, y1 in [(-q - 1, -q, q + 1, -q + 0.5), (q, -q - 1, q - 0.4, q + 1), (q + 1, q, -q - 1, q - 0.5), (-q, q + 1, -q + 0.4, -q - 1)]:
        m = np.maximum(m, mask(lambda d: stamp(d, bowed(x0, y0, x1, y1, (rng.random() - 0.5) * 1.6), taper(1.5, 0.75, 0.06))))
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
    """Paper: the rim is at full strength for 1.5 to 2.6 points, wider on one side as the colour pools, then grades
    into the wash over 3 points with no inner line. The inside is 60% of rim strength or more, never bare paper.
    Ink: opaque paint, flat, no rim, with an edge uneven from the brush."""
    inside = distance_transform_edt(shape > 0.5) / S       # points from the edge
    if ink: return np.clip(inside / 0.6, 0, 1) * (shape > 0.5), (inside > 1.0)
    yy, xx = np.mgrid[0:N, 0:N]; ang = np.arctan2(yy - C, xx - C)
    rim_w = 1.5 + 0.55 * (1 + np.sin(ang - 0.9)) + 0.25 * np.sin(3 * ang + 1.3).clip(0)      # pools low and to one side
    t = np.clip(1 - (inside - rim_w) / 3.0, 0, 1); rimness = t * t * (3 - 2 * t)
    base = 0.62 + 0.07 * dimple
    alpha = base + (1 - base) * rimness
    return alpha * (shape > 0.5), (shape > 0.5) & (inside <= 1.5) & (inside >= 0.3)

def water(state, ink=False):
    R = H
    if state == "done": return wash(wobble_shape(lambda: disc_pts(R, AMP)), ink)
    if state == "diamond":
        sh = wobble_shape(diamond_pts) * (1 - mask(lambda d: poly(d, [(-H * 2, -CUT / 2), (H * 2, -CUT / 2), (H * 2, CUT / 2), (-H * 2, CUT / 2)])))
        return wash(sh, ink)
    if state == "part":                                     # three brush strokes at full strength, each pooled at its start and lifted at its end
        dx, dy, nx, ny = math.cos(TH), -math.sin(TH), math.sin(TH), math.cos(TH); w = SIZE * 0.17
        m = mask(lambda d: [stamp(d, bowed(nx * o - dx * L, ny * o - dy * L, nx * o + dx * L, ny * o + dy * L, b), brush(w)) for o, L, b in ((-SIZE * 0.3, SIZE * 0.27, 0.3), (0, SIZE * 0.42, -0.25), (SIZE * 0.3, SIZE * 0.27, 0.2))])
        return m, m > 0.99
    if state == "paused":
        a = math.radians(-12); L = SIZE * 0.22      # a short tilted dab, so it does not read as the system's minus in a circle
        m = mask(lambda d: stamp(d, bowed(-L * math.cos(a), -L * math.sin(a), L * math.cos(a), L * math.sin(a), 0.3), brush(SIZE * 0.17))); return m, m > 0.99
    if state == "tocome":                                   # a ring of short dabs of uneven length, 2 points, gaps of 2 points or more
        r = R * 0.9; m = np.zeros((N, N)); a0 = 0.1
        while a0 < 2 * math.pi - 0.3:
            a1 = a0 + (2.4 + rng.random() * 1.6) / r
            m = np.maximum(m, mask(lambda d: stamp(d, [(r * math.cos(a0), r * math.sin(a0)), (r * 1.01 * math.cos((a0 + a1) / 2), r * 1.01 * math.sin((a0 + a1) / 2)), (r * math.cos(a1), r * math.sin(a1))], brush(2.0), 20)))
            a0 = a1 + (2.3 + rng.random() * 0.8 + GAPX) / r
        return m, m > 0.99
    if state == "notlogged":                                # one thin closed ring at the done mark's size
        o = wobble_shape(lambda: disc_pts(R * 0.98, 0.02)); i = wobble_shape(lambda: disc_pts(R * 0.98 - 1.7, 0.035)); m = np.clip(o - i, 0, 1); return m, m > 0.99
    return np.zeros((N, N)), np.zeros((N, N), bool)

def water_today():                                          # one brushed ring: pooled where it starts, thin where it lifts, gap of 1 point at most
    r = H + 5.4 + GROW * 1.2; n = 120; gap = 1.0 / r; start = -0.7
    def at(i): a = start + gap + (2 * math.pi - gap) * i / n; rr = r + 0.3 * math.sin(a * 2 + 0.6) - 0.9 * (i / n); return rr * math.cos(a), rr * math.sin(a)   # the end lands just inside the start
    def width(i): t = i / n; return max(1.5, 3.0 - 1.5 * t ** 0.7)       # 3 points where it pools at the start, thinning all the way round to 1.5 where it lifts
    return mask(lambda d: [stamp(d, [at(i), at(i + 0.5), at(i + 1)], (lambda t, w=width(i): w), 4) for i in range(n)])

# ---------- compose and measure ----------
STATES = [("done", "Done"), ("part", "Part done"), ("paused", "Paused"), ("diamond", "Logged on a paused day or a day off"), ("tocome", "To come"), ("notlogged", "Not logged"), ("today", "Today, done")]

def papers(style, ap):
    t = TOK["styles"][style][ap]; paper = hexrgb(t["paper"]); g = t.get("grain") or {"color": t["paper"], "maxAlpha": 0.0}; grain = hexrgb(g["color"])
    worst = paper * (1 - g["maxAlpha"]) + grain * g["maxAlpha"] if ap == "paper" else paper      # the pixel marks contrast least against
    tex = (tooth if style == "pencil" else dimple)[..., None]
    field = paper * (1 - g["maxAlpha"] * tex) + grain * g["maxAlpha"] * tex
    return field, worst, hexrgb(t["text"])

def heavier(m):                                             # Increase Contrast: flat, and half a point heavier, a quarter point each side
    return maximum_filter((np.asarray(m, float) > 0.5).astype(float), size=round(0.5 * S) + 1)

def render(style, ap, state, accent, outline=False, ic=False):
    global CUT, GROW, GAPX, AMP
    field, worst, text = papers(style, ap); ink = ap == "ink"
    if ic:                                                  # marks in the text colour, flat, heavier; the diamond's cut half a point wider as drawn; Watercolor loses wash and grain
        if state == "today": state, outline = "done", True
        fn = pencil if style == "pencil" else (lambda s: water(s, ink))
        GAPX, AMP = 1.5, 0.06; CUT = 1.25 + 0.5 + 0.5                              # drawn a point wider, because the heavier strokes take half a point back
        try: a, _ = fn(state)
        finally: CUT, GAPX, AMP = 1.25, 0.0, 0.035
        a = heavier(a)
        if style == "watercolor": field = np.ones_like(field) * hexrgb(TOK["styles"][style][ap]["paper"])
        img = field * (1 - a[..., None]) + text * a[..., None]
        if outline:
            GROW = 0.5
            try: ring = heavier(pencil_today() if style == "pencil" else water_today())
            finally: GROW = 0.0
            img = img * (1 - ring[..., None]) + text * ring[..., None]
        return img, ratio(float(lum(text[None])[0]), float(lum(worst[None])[0]))
    fn = pencil if style == "pencil" else (lambda s: water(s, ink))
    strength = TOK["markAlpha"][style] if not (style == "watercolor" and ink) else 1.0
    if state == "today": state, outline = "done", True
    a, core = fn(state); ring = (pencil_today() if style == "pencil" else water_today()) if outline else None
    a = a * strength
    if style == "pencil" and ink:
        accent = accent + (1 - accent) * 0.22                                   # the same hue as a lighter pencil
        a = a * np.where((speck < 0.2) & (np.asarray(core) < 0.5), 0.0, 1.0)   # charcoal specks at the edges and between strokes; the core stays solid
    img = field * (1 - a[..., None]) + accent * a[..., None]
    if ring is not None: img = img * (1 - ring[..., None]) + text * ring[..., None]
    core = np.asarray(core) > 0.5
    if core.any():
        drawn = worst * (1 - a[core][:, None]) + accent * a[core][:, None]          # the mark as drawn, over the worst paper pixel
        ls = lum(drawn); lw = float(lum(worst[None])[0]); cr = min(ratio(float(l), lw) for l in (ls.min(), ls.max()))
    else: cr = float("nan")
    return img, cr

def solve(base, worst, strength, ink):
    """The nearest shade of a hue that holds 3:1 as drawn: darker on Paper, lighter on Ink."""
    lw = float(lum(worst[None])[0])
    for k in np.linspace(0, 1, 201):
        c = base + (1 - base) * k if ink else base * (1 - k)
        if ratio(float(lum((c * strength + worst * (1 - strength))[None])[0]), lw) >= 3.0: return c, k
    return c, 1.0

def measures():
    """The numbers the accessibility review asked for beyond the first table."""
    blue = hexrgb(TOK["swatches"]["blue"]); g = lambda im: lum(gaussian_filter(im, sigma=(0.75 * S, 0.75 * S, 0)))
    print("\nAfter a blur of 0.75 points, lowest contrast inside the mark, and the today outline as drawn:")
    print(f"{'style':11} {'paper':6} {'done':>6} {'diamond':>8} {'to come':>8} {'not logged':>11} {'today outline':>14}")
    yy, xx = np.mgrid[0:N, 0:N]
    for style in ("pencil", "watercolor"):
        for ap in ("paper", "ink"):
            field, worst, text = papers(style, ap); lw = float(lum(worst[None])[0]); out = []
            inner = (np.abs(xx - C) < (H - 3.5) * S) & (np.abs(yy - C) < (H - 3.5) * S) if style == "pencil" else ((xx - C) ** 2 + (yy - C) ** 2 < ((H - 3.5) * S) ** 2)
            b = g(render(style, ap, "done", blue)[0]); out.append(min(ratio(float(v), lw) for v in (b[inner].min(), b[inner].max())))
            b = g(render(style, ap, "diamond", blue)[0]); tri = (np.abs(xx - C) + np.abs(yy - C) < (H - 4) * S) & (np.abs(yy - C) > 2.2 * S)
            out.append(min(ratio(float(v), lw) for v in (b[tri].min(), b[tri].max())))
            for st in ("tocome", "notlogged"):
                b = g(render(style, ap, st, blue)[0]); out.append(max(ratio(float(v), lw) for v in (b.min(), b.max())))
            out.append(ratio(float(lum(text[None])[0]), lw))
            print(f"{style:11} {ap:6} {out[0]:>6.2f} {out[1]:>8.2f} {out[2]:>8.2f} {out[3]:>11.2f} {out[4]:>14.2f}")
    print("\nOther colours as drawn, on the solid part of a mark. Custom hues are shaded until they hold 3:1:")
    print(f"{'style':11} {'paper':6} {'ochre swatch':>13} {'yellow, raw':>12} {'yellow, shaded':>15} {'red, raw':>9} {'red, shaded':>12}")
    for style in ("penAndInk", "pencil", "watercolor"):
        for ap in ("paper", "ink"):
            field, worst, text = papers(style, ap); lw = float(lum(worst[None])[0]); ink = ap == "ink"
            strength = TOK["markAlpha"][style] if not (style == "watercolor" and ink) else 1.0
            cr = lambda c: ratio(float(lum((c * strength + worst * (1 - strength))[None])[0]), lw)
            row = [cr(hexrgb(TOK["swatches"]["ochre"]))]
            for raw in ("#F5C400", "#D92B1F"):
                c = hexrgb(raw); sc, k = solve(c, worst, strength, ink); row += [cr(c), cr(sc)]
                if style == "penAndInk": row[-1] = (row[-1], "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in sc))
            f = lambda v: (f"{v[0]:.2f} {v[1]}" if isinstance(v, tuple) else f"{v:.2f}")
            print(f"{style:11} {ap:6} {f(row[0]):>13} {f(row[1]):>12} {f(row[2]):>15} {f(row[3]):>9} {f(row[4]):>12}")

def main(out, ic=False):
    font = ImageFont.load_default(); accent = hexrgb(TOK["swatches"]["blue"])
    cell = N // 2; pad = 14; lab = 170
    rows = [(st, ap) for st in ("pencil", "watercolor") for ap in ("paper", "ink")]
    sheet = Image.new("RGB", (lab + len(STATES) * (2 * cell + pad), 40 + len(rows) * (cell + pad)), (236, 233, 226)); d = ImageDraw.Draw(sheet)
    for ci, (_, name) in enumerate(STATES): d.text((lab + ci * (2 * cell + pad), 8), name[:34], fill=(0, 0, 0), font=font); d.text((lab + ci * (2 * cell + pad), 22), "sharp, blurred 0.75 pt", fill=(90, 90, 90), font=font)
    print(f"{'style':11} {'paper':6} " + " ".join(f"{n[:11]:>11}" for _, n in STATES[:6]))
    for ri, (style, ap) in enumerate(rows):
        y = 40 + ri * (cell + pad); d.text((10, y + cell // 2 - 6), f"{style}, {ap}", fill=(0, 0, 0), font=font); crs = []
        for ci, (st, _) in enumerate(STATES):
            img, cr = render(style, ap, st, accent, ic=ic); crs.append(cr)
            sharp = Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8")).resize((cell, cell), Image.LANCZOS)
            bl = Image.fromarray((np.clip(gaussian_filter(img, sigma=(0.75 * S, 0.75 * S, 0)), 0, 1) * 255).astype("uint8")).resize((cell, cell), Image.LANCZOS)
            x = lab + ci * (2 * cell + pad); sheet.paste(sharp, (x, y)); sheet.paste(bl, (x + cell, y))
        print(f"{style:11} {ap:6} " + " ".join(f"{c:>11.2f}" for c in crs[:6]))
    sheet.save(out); print(sheet.size)
    if not ic: measures()

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "m4-marks.png", ic="ic" in sys.argv[2:])
