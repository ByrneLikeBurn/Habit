"""Experiment, 16 November 2026: how close can a computed painting come to the marks of real watercolour?

    python3 wc.py <out.jpg>

One pigment only. The owner said the scenes are passable drawings and not watercolours, and that pigment count is not the issue.
The marks this tries to make, each named where it is made:
  1. wet into wet     a shape painted on wet paper has no edge. It feathers outward unevenly.
  2. the dried edge   a shape painted on dry paper keeps a hard edge with a darker line of pigment along it.
  3. pooling          a wash is not flat. Pigment drifts inside it and settles toward the bottom of the stroke.
  4. backruns         where water ran back into a drying wash it leaves a pale bloom with a dark crinkled fringe.
  5. granulation      pigment settles in the hollows of the paper. It follows the paper, and is stronger in dark washes.
  6. glazing          a second transparent wash over a dry one. Both edges stay visible.
  7. dry brush        a fast stroke with little water skips the hollows of the paper and leaves it bare.
  8. the brush        shapes are made of a few strokes, loose and a little wrong. Nothing is outlined or filled evenly.
"""
from __future__ import annotations

import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from paint import XN, YN, H, W, SS, smoothstep, noise, fbm
from tint import tint, to_image

XX, YP = XN * W, YN * H
rng = np.random.default_rng(11)
PAPER = 0.6 * noise(901, 5.0) + 0.4 * noise(902, 2.0)             # cold-pressed paper: broad hollows and a finer tooth
PAPER = PAPER / PAPER.std()


class Sheet:
    def __init__(self): self.T = np.ones((H, W))                   # 1 is bare paper

    def wash(self, field, density, wet=0.0, edge=0.55, edge_w=7.0, pool=0.25, vary=0.30, gran=0.10, seed=1, wander=None):
        """field: signed distance in pixels, positive inside. wet: 0 dry paper, 1 very wet paper."""
        w = wet * 26.0 if wander is None else wander                                 # how far the edge strays. Small for a trunk, which must stay straight
        f = field + w * fbm(seed, 34.0, octaves=3) + (1 - wet) * min(2.2, w + 0.6) * noise(seed + 1, 7.0)   # 1 and 8: the edge wanders
        soft = 1.5 + 46.0 * wet ** 1.5
        m = smoothstep(-soft, soft * 0.35, f)                                          # 1: feathered when wet
        d = density * (1.0 + vary * fbm(seed + 2, 90.0, octaves=2, sigma_x=60.0))      # 3: pigment drifts inside the wash
        if pool:
            ys = np.where(m.max(axis=1) > 0.05)[0]
            if len(ys): d = d * (1.0 - pool + 2 * pool * smoothstep(ys[0], ys[-1], YP) ** 1.5)   # 3: and settles downward
        if edge and wet < 0.5:
            inside = ndi.distance_transform_edt(f > 0)
            line = np.exp(-inside / edge_w) * (0.6 + 0.4 * smoothstep(-0.6, 0.6, noise(seed + 3, 40.0)))
            d = d * (1.0 + edge * (1 - 2 * wet) * line - 0.12 * np.exp(-((inside - 4 * edge_w) / (3 * edge_w)) ** 2))   # 2: the dried edge
        d = d * (1.0 + gran * (0.5 + d) * PAPER)                                       # 5: granulation follows the paper
        self.T *= 1.0 - np.clip(d * m, 0.0, 0.96)                                      # 6: glazes multiply
        return m

    def bloom(self, cx, cy, r, seed, lift=0.42, fringe=0.30):
        """4: a backrun. Pale inside, with a dark, crinkled fringe where the pigment was pushed."""
        rr = np.hypot(XX - cx * W, (YP - cy * H) * 1.15) / (r * H) + 0.22 * fbm(seed, 26.0, octaves=3) + 0.05 * noise(seed + 1, 5.0)
        painted = smoothstep(0.02, 0.2, 1.0 - self.T)
        self.T = self.T + (1.0 - self.T) * lift * smoothstep(1.0, 0.55, rr) * painted
        self.T *= 1.0 - fringe * np.exp(-((rr - 1.0) / 0.045) ** 2) * painted

    def dry(self, field, density, seed, skip=0.15):
        """7: dry brush. The stroke only catches the high parts of the paper."""
        m = smoothstep(-1.5, 1.0, field) * smoothstep(skip - 0.5, skip + 0.5, -PAPER + 0.5 * noise(seed, 3.0, sigma_x=30.0))
        self.T *= 1.0 - np.clip(density * m, 0, 0.9)

    def finish(self):
        img = Image.fromarray(np.clip(self.T, 0, 1).astype(np.float32), mode="F").resize((W // SS, H // SS), Image.LANCZOS)
        return np.clip(np.asarray(img).astype(float), 0, 1)


def stroke(x, top, base, half, lean=0.0, flare=0.5, seed=0):
    """One loaded brush stroke pulled down the paper: a trunk. It wobbles, swells and spreads at its foot."""
    r = np.random.default_rng(seed)
    wob = ndi.gaussian_filter1d(r.standard_normal(H), 60.0); wob = wob / wob.std() * 0.004 * W
    swell = 1.0 + 0.10 * ndi.gaussian_filter1d(r.standard_normal(H), 80.0) / 0.1 * 0.08
    t = np.clip((YN - top) / max(base - top, 1e-6), 0, 1)
    hw = half * W * swell[:, None] * (1.0 + flare * np.exp(-np.clip(base - YN, 0, 1) / 0.05))
    cx = (x + lean * (1 - t)) * W + wob[:, None]
    return np.minimum(hw - np.abs(XX - cx), np.minimum((YN - top) * H + 20, (base - YN) * H + 4))


def dab(x, y, rx, ry, seed):
    """One touch of a full brush: an uneven blot."""
    return (1.0 - np.sqrt(((XX - x * W) / (rx * W)) ** 2 + ((YP - y * H) / (ry * H)) ** 2)) * min(rx * W, ry * H)


def frond(x, y, ang, L, width):
    """One quick curved stroke, thick where the brush landed and thin where it lifted: a fern frond."""
    f = np.full((H, W), -99.0); n = 14; px, py = x * W, y * H
    for i in range(1, n + 1):
        t = i / n
        qx = x * W + np.sin(ang) * L * H * t * (1 + 0.2 * t); qy = y * H - np.cos(ang) * L * H * t + 0.5 * abs(np.sin(ang)) * L * H * t * t
        w = width * H * np.sin(np.pi * min(t * 0.9 + 0.1, 1.0)) ** 0.8 + 0.6
        pad = int(w + 4); xa, xb = int(max(min(px, qx) - pad, 0)), int(min(max(px, qx) + pad, W - 1)) + 1
        ya, yb = int(max(min(py, qy) - pad, 0)), int(min(max(py, qy) + pad, H - 1)) + 1
        if xa < xb and ya < yb:
            xs, ys = np.meshgrid(np.arange(xa, xb), np.arange(ya, yb)); dx, dy = qx - px, qy - py
            tt = np.clip(((xs - px) * dx + (ys - py) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
            f[ya:yb, xa:xb] = np.maximum(f[ya:yb, xa:xb], w - np.hypot(xs - (px + tt * dx), ys - (py + tt * dy)))
        px, py = qx, qy
    return f


def conifers() -> np.ndarray:
    s = Sheet()
    # the light behind the grove, laid on wet paper: deeper at the top corners, bare paper kept in the middle
    s.wash(np.full((H, W), 60.0), 0.05 + 0.30 * smoothstep(0.55, 0.0, YN) * (0.45 + 1.1 * np.abs(XN - 0.52)), wet=0.0, edge=0, pool=0, vary=0.5, seed=21)
    s.bloom(0.36, 0.20, 0.20, 31); s.bloom(0.71, 0.13, 0.15, 33)
    # foliage dropped into the wet top of the paper: it has no edges
    for i, (x, y, rx, ry, d) in enumerate([(.20, .02, .09, .16, .30), (.33, .08, .07, .13, .22), (.47, .00, .08, .14, .26), (.60, .07, .07, .15, .22),
                                           (.76, .01, .09, .17, .30), (.88, .09, .06, .12, .20)]):
        s.wash(dab(x, y, rx, ry, i), d, wet=0.85, edge=0, pool=0, seed=41 + 3 * i)
    # far trunks, touched in while the paper was still wet
    for i, (x, half, d) in enumerate([(.305, .010, .16), (.385, .013, .20), (.465, .008, .14), (.555, .012, .19), (.640, .009, .15), (.725, .012, .20)]):
        s.wash(stroke(x, -0.2, 0.66, half, flare=0.2, seed=60 + i), d, wet=0.55, edge=0, pool=0.1, seed=61 + 3 * i)
    # the floor: wet at its far edge, deeper toward the viewer
    s.wash((YN - 0.62 - 0.02 * noise(71, 60.0, sigma_x=200.0)) * H, 0.16 + 0.34 * smoothstep(0.62, 1.0, YN) ** 1.4, wet=0.35, edge=0, pool=0, vary=0.4, seed=72)
    s.bloom(0.50, 0.80, 0.12, 75, lift=0.3)
    # middle trunks on damp paper: one soft edge, a faint line on the other
    for i, (x, half, d, base) in enumerate([(.245, .020, .40, .74), (.425, .028, .50, .78), (.598, .018, .36, .73), (.690, .026, .46, .77), (.815, .022, .42, .75)]):
        s.wash(stroke(x, -0.2, base, half, lean=0.004 * (i % 3 - 1), flare=0.35, seed=80 + i), d, wet=0.16, edge=0.45, edge_w=5, seed=81 + 3 * i)
    # two near trunks on dry paper: hard edges, the dark line of dried pigment, pigment pooled at the foot
    for i, (x, half, d, base, lean) in enumerate([(.085, .074, .70, .95, .008), (.935, .058, .62, .92, -.006)]):
        f = stroke(x, -0.2, base, half, lean=lean, flare=0.6, seed=90 + i)
        s.wash(f, d, wet=0.0, edge=0.75, edge_w=8, pool=0.22, seed=91 + 3 * i)
        for j in range(4):                                                    # 6: bark as a second glaze, a few long strokes with their own edges
            g = stroke(x + (j - 1.5) * half * 0.42 + 0.004 * rng.standard_normal(), -0.2, base - 0.03 * j, half * (0.10 + 0.05 * rng.random()), lean=lean, flare=0.9, seed=95 + 7 * i + j)
            s.wash(np.minimum(g, f - 3), 0.30, wet=0.05, edge=0.5, edge_w=3, pool=0.1, vary=0.4, seed=96 + 5 * j + 20 * i)
        s.dry(np.minimum(stroke(x - half * 0.55, -0.2, base, half * 0.22, lean=lean, flare=0.6, seed=99 + i), f - 2), 0.5, 99 + i)   # 7: dry brush on the lit side
    # ferns: quick strokes, a wet shadow under each clump
    for i, (x, y, L, nf) in enumerate([(.19, .955, .19, 7), (.33, .93, .15, 6), (.47, .965, .21, 8), (.61, .935, .16, 6), (.75, .96, .20, 7), (.86, .94, .15, 6)]):
        s.wash(dab(x, y + 0.02, 0.07, 0.05, i), 0.32, wet=0.6, edge=0, pool=0, seed=121 + i)
        f = np.full((H, W), -99.0)
        for j in range(nf):
            a = np.radians(-70 + 140 * (j + 0.5 + 0.4 * (rng.random() - 0.5)) / nf)
            f = np.maximum(f, frond(x, y, a, L * (0.75 + 0.4 * rng.random()), 0.016))
        s.wash(f, 0.62, wet=0.0, edge=0.35, edge_w=2.5, pool=0.1, vary=0.4, gran=0.06, seed=131 + 3 * i)
    return s.finish()


def straight(x, d, girth=1.0, lean=0.0):
    """A trunk on the ground plane of redwoods.py: straight, slightly tapered, flared at the foot. Returns field, base, half, density."""
    from redwoods import tree
    base, half, dens = tree(d, girth)
    t = np.clip((base - YN) / (base + 0.3), 0, 1.5)
    hw = half * W * (1.0 - 0.10 * t) * (1.0 + (0.35 + 0.35 * d) * np.exp(-np.clip(base - YN, 0, 1) / (0.03 + 0.05 * d)))
    cx = (x + lean * t) * W
    return np.minimum(hw - np.abs(XX - cx), (base - YN) * H + 3), base, half, dens


def redwoods_painted() -> np.ndarray:
    """The second Redwoods drawing (straight trunks, one ground plane, ferns) painted with the marks of watercolour.

    Form comes from the drawing. Paint behaviour comes from how wet the paper was: far is wet, near is dry.
    Trunks do not wander and there are no backrun lines.
    """
    import redwoods as rw
    s = Sheet()
    s.wash(np.full((H, W), 60.0), 0.05 + 0.26 * smoothstep(0.5, 0.0, YN) * (0.5 + 1.0 * np.abs(XN - 0.52)), edge=0, pool=0, vary=0.5, seed=21)
    for i, (x, y, rx, ry, d) in enumerate([(.24, .00, .08, .15, .26), (.38, .05, .07, .12, .20), (.52, .00, .08, .13, .22), (.66, .05, .07, .14, .20), (.79, .00, .08, .15, .26)]):
        s.wash(dab(x, y, rx, ry, i), d, wet=0.8, edge=0, pool=0, seed=41 + 3 * i)          # foliage dropped into the wet top of the paper
    s.wash((YN - 0.61) * H, 0.14 + 0.36 * smoothstep(0.61, 1.0, YN) ** 1.3, wet=0.3, edge=0, pool=0, vary=0.35, seed=72, wander=5.0)
    trees = sorted([(.300, .08, 1.0, 0), (.372, .14, 1.2, 0), (.455, .06, .9, 0), (.535, .16, 1.1, 0), (.628, .10, 1.0, 0), (.700, .20, 1.2, 0), (.770, .07, .9, 0),
                    (.238, .42, 1.0, .004), (.418, .52, 1.15, -.003), (.585, .36, .9, .003), (.672, .60, 1.0, -.004), (.805, .46, 1.1, .002),
                    (.085, 1.0, 1.15, .010), (.930, .86, 1.0, -.008)], key=lambda t: t[1])
    for i, (x, d, girth, lean) in enumerate(trees):
        f, base, half, dens = straight(x, d, girth, lean)
        wet = 0.5 * (1 - d) ** 1.5                                                    # far trunks went in while the paper was wet
        m = smoothstep(-1.5, 1.0, f) if wet < 0.1 else smoothstep(-(1.5 + 46 * wet ** 1.5), (1.5 + 46 * wet ** 1.5) * 0.35, f)
        s.T = s.T + (1 - s.T) * m * (0.9 if d > 0.3 else 0.5)                          # a nearer trunk covers what is behind it
        s.wash(f, dens, wet=wet, edge=0.7 * d, edge_w=4 + 5 * d, pool=0.18 * d, vary=0.2 + 0.15 * d, seed=200 + 7 * i, wander=1.2)
        if d > 0.3:                                                                   # bark: a second glaze of long straight strokes that follow the flare
            n = 3 + int(5 * d)
            for j in range(n):
                off = (j + 0.5 + 0.3 * (rng.random() - 0.5)) / n * 2 - 1
                g, *_ = straight(x + off * half * 0.82, d, girth * (0.05 + 0.05 * rng.random()), lean)
                s.wash(np.minimum(g, f - 2), 0.22 + 0.12 * d, wet=0.04, edge=0.4, edge_w=2.5, pool=0.1, vary=0.5, seed=300 + 11 * i + j, wander=0.8)
        if d > 0.8: s.dry(np.minimum(straight(x - half * 0.5, d, girth * 0.2, lean)[0], f - 2), 0.4, 400 + i)
    # ferns: the fronds of the drawing, painted crisp on dry paper, with a wet shadow under each clump
    for k, (clumps, dens, lw) in enumerate([([(x, .70 + .012 * (i % 3), .07, 6) for i, x in enumerate(np.linspace(.22, .82, 9))], 0.10, 0.9),
                                            ([(.20, .83, .13, 7), (.32, .79, .11, 6), (.50, .86, .14, 7), (.62, .80, .11, 6), (.76, .84, .13, 7)], 0.20, 1.2),
                                            ([(.19, .965, .22, 8), (.34, .975, .19, 7), (.49, .955, .23, 8), (.63, .975, .20, 7), (.77, .96, .22, 8), (.99, .96, .19, 7)], 0.30, 1.5)]):
        r2 = np.random.default_rng(500 + k); f = np.full((H, W), -99.0)
        for x, y, size, nf in clumps:
            for j in range(nf):
                a = np.radians(-68 + 136 * (j + 0.5 + 0.5 * (r2.random() - 0.5)) / nf)
                rw.frond(f, x * W, y * H, a, size * H * (0.75 + 0.4 * r2.random()) * (1.0 - 0.25 * abs(np.sin(a))), r2, lw)
        m = np.clip(f + 0.6, 0, 1); s.T = s.T + (1 - s.T) * m * 0.92                      # lit fronds: paper kept, then a light wash
        s.wash(f, dens, wet=0.0, edge=0.3, edge_w=1.5, pool=0.0, vary=0.3, gran=0.05, seed=540 + k, wander=0.3)
    return s.finish()


if __name__ == "__main__":
    v = redwoods_painted() if "redwoods" in sys.argv[2:] else conifers()
    Image.fromarray((v * 255 + 0.5).astype(np.uint8), mode="L").save("/tmp/wc-value.png")
    cells = [to_image(tint(v, p)) for p in ("midday", "sunset", "night")]
    pad = 14; w, h = cells[0].size
    sheet = Image.new("RGB", (w + 2 * pad, (h + pad) * len(cells) + pad + 118 + pad), (250, 248, 244))
    for i, c in enumerate(cells): sheet.paste(c, (pad, pad + i * (h + pad)))
    for i, c in enumerate(cells): sheet.paste(c.resize((350, 118), Image.LANCZOS), (pad + i * 364, pad + len(cells) * (h + pad)))
    sheet.save(sys.argv[1], quality=90); print(sheet.size)
