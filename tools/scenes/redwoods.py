"""Redwoods scene. Run: python3 redwoods.py <out_dir> [a b c]

Not approved by the owner. Variants for the scene gate only.

What failed before (docs/spec.md and docs/scenes/redwoods/review.md): trunks in a row (a barcode); a corridor with
drooping boughs (eerie); round dabs (camouflage); sticks with needle lines (sickly pines); see-through trunks with
no undergrowth (columns in a hall).

How this version is built: one ground plane. A tree's depth sets where its base sits, how wide it is and how dark it is.
Shapes are painted from far to near and each one covers what is behind it. Ferns cover the floor and the trunk bases.
Sprays of foliage cross in front of trunks and hang between them at the top.
"""
from __future__ import annotations

import sys
import numpy as np
from scipy import ndimage as ndi
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise

XX = XN * W
YP = YN * H


def stamp(f, x0, y0, x1, y1, w0, w1):
    """Add one tapered stroke to the signed field f. Pixel coordinates. Only the stroke's own window is touched."""
    pad = max(w0, w1) + 3
    xa, xb = int(max(min(x0, x1) - pad, 0)), int(min(max(x0, x1) + pad, W - 1)) + 1
    ya, yb = int(max(min(y0, y1) - pad, 0)), int(min(max(y0, y1) + pad, H - 1)) + 1
    if xa >= xb or ya >= yb: return
    xs, ys = np.meshgrid(np.arange(xa, xb), np.arange(ya, yb))
    dx, dy = x1 - x0, y1 - y0; L2 = max(dx * dx + dy * dy, 1e-6)
    t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / L2, 0, 1)
    d = np.hypot(xs - (x0 + t * dx), ys - (y0 + t * dy))
    f[ya:yb, xa:xb] = np.maximum(f[ya:yb, xa:xb], (w0 + (w1 - w0) * t) - d)


MIX = np.zeros((H, W))      # experiment: which of two pigments each area takes. 0 is the leaf pigment, 1 is the earth pigment
SOFT = np.zeros((H, W))     # experiment: how wet the paper was. 1 is far and soft, 0 is near and crisp


def mark(m, mix, soft):
    MIX[:] = MIX * (1 - m) + mix * m
    SOFT[:] = SOFT * (1 - m) + soft * m


def cover(p, m, density, seed, mix=0.0, soft=0.0, **kw):
    """Paint a shape so that it hides what is behind it: lift its area back to paper, then lay its wash."""
    p.lift(m)
    p.wash(m, density, seed=seed, **kw)
    mark(m, mix, soft)


def tree(d, girth=1.0):
    """Where a tree of depth d (0 far, 1 near) stands: (base y, half width, density). One ground plane for every tree."""
    return 0.615 + 0.335 * d ** 1.15, girth * (0.0075 + 0.078 * d ** 1.7), 0.17 + 0.67 * d ** 0.9


def trunk(p, x, d, seed, girth=1.0, lean=0.0):
    base, half, dens = tree(d, girth)
    t = np.clip((base - YN) / (base + 0.3), 0, 1.5)
    hw = half * W * (1.0 - 0.10 * t) * (1.0 + (0.35 + 0.35 * d) * np.exp(-np.clip(base - YN, 0, 1) / (0.03 + 0.05 * d)))
    cx = (x + lean * t) * W
    f = np.where(YN <= base + 0.012, hw - np.abs(XX - cx), -9.0)
    m = p.ragged(f, edge=1.2 + 0.6 * d, rough=0.5 + 0.7 * d, fine=1.0, tooth=0.4 + 0.5 * d, seed=seed) * (f > -5)
    u = (XX - cx) / np.maximum(hw, 1.0)                                       # -1 at the left edge, 1 at the right
    side = 0.80 + 0.20 * smoothstep(-0.9, 0.9, u)                             # the side away from the light is deeper
    cover(p, m, dens * side, seed + 1, mix=1.0, soft=1.0 - d, rim=0.18, rim_w=3 + 2 * d, gran=0.07, flow=0.08)
    # bark: long fibrous furrows that follow the flare, dark and light, broken along their length
    rng = np.random.default_rng(seed + 2)
    k = 26 + 40 * girth * d
    n = ndi.gaussian_filter1d(rng.standard_normal(4096), 9.0); n /= n.std()
    wob = 0.03 * noise(seed + 3, 3.0, sigma_x=2.0)
    idx = np.clip(((u + wob) * k + 2048).astype(int), 0, 4095)
    along = 0.55 + 0.45 * smoothstep(-0.6, 0.6, noise(seed + 4, 60.0, sigma_x=3.0))
    inside = m * smoothstep(1.0, 0.75, np.abs(u))
    p.wash(inside * smoothstep(0.5, 1.3, n[idx]) * along, 0.20 + 0.25 * d, rim=0, gran=0.04, flow=0.0, seed=seed + 5)
    p.lift((0.10 + 0.16 * d) * inside * smoothstep(0.6, 1.4, -n[idx]) * along)
    return base, half


def frond(f, bx, by, ang, L, rng, lw):
    """One fern frond: an arching stem with pinnae on both sides, longest a third of the way up, none at the tip."""
    n = max(int(L / 5.6), 7); sx = np.sin(ang); px, py = bx, by
    droop = 0.45 + 0.5 * abs(sx)
    for i in range(1, n + 1):
        t = i / n
        x = bx + sx * L * t * (1.0 + 0.15 * t); y = by - np.cos(ang) * L * t + droop * L * t * t * 0.55
        stamp(f, px, py, x, y, lw * (1.0 - 0.7 * t) + 0.3, lw * (1.0 - 0.7 * t) + 0.2)
        tx, ty = x - px, y - py; tl = max(np.hypot(tx, ty), 1e-6); tx, ty = tx / tl, ty / tl
        ln = 0.30 * L * np.sin(np.pi * min(t * 1.25 + 0.05, 1.0) ** 0.8) * (1.0 - 0.5 * t) * (0.85 + 0.3 * rng.random())
        if ln > 1.2:
            for sgn in (1.0, -1.0):                                           # pinnae sweep toward the tip
                stamp(f, x, y, x + ln * (0.45 * tx - sgn * 0.89 * ty), y + ln * (0.45 * ty + sgn * 0.89 * tx), max(lw * 0.8, 1.0), 0.3)
        px, py = x, y


def ferns(p, clumps, density, seed, light=0.0, soft=0.0):
    """Clumps of sword fern. clumps: (x, y, size, fronds), normalised, size as a share of the card's height."""
    rng = np.random.default_rng(seed)
    f = np.full((H, W), -99.0)
    for x, y, size, nf in clumps:
        for j in range(nf):
            a = np.radians(-72 + 144 * (j + 0.5 + 0.5 * (rng.random() - 0.5)) / nf)
            frond(f, x * W, y * H, a, size * H * (0.75 + 0.4 * rng.random()) * (1.0 - 0.25 * abs(np.sin(a))), rng, max(size * H * 0.011, 1.0))
    m = np.clip(f + 0.6, 0.0, 1.0)
    cover(p, m, density, seed + 1, mix=0.0, soft=soft, rim=0.0, gran=0.06, flow=0.12)
    if light: p.lift(light * m * smoothstep(-0.2, 0.8, noise(seed + 2, 12.0)))


def sprays(p, items, density, seed, needle=0.030):
    """Flat sprays of foliage, as a redwood carries them. items: (x0, y0, x1, y1, twigs) is one small branch with side twigs."""
    rng = np.random.default_rng(seed)
    f = np.full((H, W), -99.0)
    for x0, y0, x1, y1, twigs in items:
        ax, ay, bx, by = x0 * W, y0 * H, x1 * W, y1 * H
        stamp(f, ax, ay, bx, by, 1.6, 0.6)
        dx, dy = bx - ax, by - ay; L = np.hypot(dx, dy); ux, uy = dx / L, dy / L
        for k in range(twigs):
            t = (k + 0.6) / (twigs + 0.4); sgn = 1.0 if k % 2 == 0 else -1.0
            sxp, syp = ax + dx * t, ay + dy * t
            tl = L * (0.50 - 0.22 * t) * (0.8 + 0.4 * rng.random())
            ex, ey = sxp + tl * (0.72 * ux - sgn * 0.69 * uy), syp + tl * (0.72 * uy + sgn * 0.69 * ux) + 0.10 * tl
            stamp(f, sxp, syp, ex, ey, 1.4, 0.5)
            vx, vy = (ex - sxp) / tl, (ey - syp) / tl
            nn = max(int(tl / 3.4), 5)
            for i in range(nn):                                                # needles in two ranks along each twig
                q = (i + 0.5) / nn; qx, qy = sxp + (ex - sxp) * q, syp + (ey - syp) * q
                ln = needle * H * (0.5 + 0.6 * np.sin(np.pi * q)) * (0.85 + 0.3 * rng.random())
                for s2 in (1.0, -1.0):
                    stamp(f, qx, qy, qx + ln * (0.5 * vx - s2 * 0.87 * vy), qy + ln * (0.5 * vy + s2 * 0.87 * vx), 1.1, 0.25)
    m = np.clip(f + 0.6, 0.0, 1.0)
    cover(p, m, density, seed + 1, rim=0.0, gran=0.06, flow=0.12)


def ground(p, y0, seed):
    """The forest floor, from the far edge of the grove down to the bottom of the card, deeper as it comes near."""
    edge = p.profile([(-0.05, y0), (.25, y0 - .012), (.5, y0 + .008), (.75, y0 - .01), (1.05, y0)], wobble=0.003, wobble_sigma=14, seed=seed)
    m = p.ragged(p.below(edge), edge=4.0, rough=2.0, fine=2.0, tooth=0.8, seed=seed + 1)
    p.wash(m, 0.16 + 0.42 * smoothstep(y0, 1.0, YN) ** 1.3, rim=0, gran=0.085, flow=0.22, flow_sigma=30, flow_aspect=5.0, seed=seed + 2)
    mark(m, 0.7, 0.7)


def grove(seed, trees, far_ferns, mid_ferns, near_ferns, hang, cross, top=0.10):
    p = Painting(paper_seed=seed)
    MIX[:] = 0.1; SOFT[:] = 1.0
    # light at the back of the grove: pale at the centre, a little deeper toward the top and the sides
    p.wash(np.ones_like(YN), 0.05 + 0.13 * smoothstep(0.45, 0.0, YN) + 0.05 * np.abs(XN - 0.5) * 2, rim=0, gran=0.05, flow=0.2, seed=seed + 1)
    ground(p, 0.60, seed + 2)
    order = sorted(trees, key=lambda t: t[1])
    stage = 0
    for i, (x, d, girth, lean) in enumerate(order):
        if stage == 0 and d > 0.30:
            p.lift(0.22 * np.exp(-((YN - 0.63) / 0.07) ** 2))                  # thin mist at the feet of the far trees. They stay solid.
            ferns(p, far_ferns, 0.12, seed + 40, soft=0.9); stage = 1
        if stage == 1 and d > 0.70:
            sprays(p, hang, 0.36, seed + 50, needle=0.034)
            ferns(p, mid_ferns, 0.24, seed + 60, light=0.2, soft=0.45); stage = 2
        trunk(p, x, d, seed + 100 + 11 * i, girth, lean)
    sprays(p, cross, 0.44, seed + 70, needle=0.040)
    ferns(p, near_ferns, 0.36, seed + 80, light=0.2)       # lit fronds over the dark floor
    return p.finish()


def variant_a() -> np.ndarray:
    """Grove. Two giants of different girth near the sides, cut by the card. Five mid trunks, uneven. Seven far trunks. Ferns everywhere."""
    trees = [(.300, .08, 1.0, 0), (.372, .14, 1.2, 0), (.455, .06, .9, 0), (.535, .16, 1.1, 0), (.628, .10, 1.0, 0), (.700, .20, 1.2, 0), (.770, .07, .9, 0),
             (.238, .42, 1.0, .004), (.418, .52, 1.15, -.003), (.585, .36, .9, .003), (.672, .60, 1.0, -.004), (.805, .46, 1.1, .002),
             (.085, 1.0, 1.15, .010), (.930, .86, 1.0, -.008)]
    far = [(x, .685 + .012 * (i % 3), .07, 6) for i, x in enumerate(np.linspace(.20, .84, 11))]
    mid = [(.20, .82, .13, 8), (.31, .78, .11, 7), (.47, .85, .14, 8), (.56, .79, .11, 7), (.63, .87, .14, 8), (.76, .82, .13, 8), (.86, .79, .11, 7)]
    near = [(.17, .955, .21, 9), (.31, .965, .19, 9), (.45, .945, .22, 10), (.60, .965, .20, 9), (.74, .95, .22, 10), (.88, .965, .20, 9), (1.0, .95, .19, 8)]
    hang = [(.34, -.03, .30, .20, 9), (.36, -.03, .40, .14, 7), (.505, -.03, .49, .22, 9), (.60, -.03, .645, .18, 8), (.76, -.03, .735, .23, 9), (.79, -.03, .83, .13, 7)]
    cross = [(.170, .26, .300, .34, 9), (.165, .44, .270, .50, 8), (.850, .34, .740, .42, 9), (.855, .52, .775, .57, 7), (.19, .62, .26, .655, 6)]
    return grove(57, trees, far, mid, near, hang, cross)


def variant_b() -> np.ndarray:
    """One giant. A single giant right of centre fills the height. The grove steps back to the left. Ferns everywhere."""
    trees = [(.105, .10, 1.0, 0), (.180, .18, 1.2, 0), (.262, .07, .9, 0), (.345, .14, 1.1, 0), (.430, .09, 1.0, 0), (.520, .19, 1.1, 0), (.905, .12, 1.0, 0), (.965, .20, 1.1, 0),
             (.060, .50, 1.1, .004), (.230, .38, .95, -.003), (.395, .58, 1.1, .003), (.495, .42, .9, -.002),
             (.720, 1.0, 1.25, -.008)]
    far = [(x, .685 + .012 * (i % 3), .07, 6) for i, x in enumerate(np.linspace(.04, .98, 14))]
    mid = [(.03, .82, .13, 8), (.15, .79, .11, 7), (.30, .84, .14, 8), (.45, .81, .13, 8), (.56, .86, .14, 8), (.89, .82, .13, 8), (.98, .85, .13, 7)]
    near = [(.05, .955, .21, 9), (.20, .965, .19, 9), (.35, .945, .22, 10), (.50, .965, .20, 9), (.62, .95, .21, 9), (.86, .955, .22, 10), (.99, .965, .19, 8)]
    hang = [(.13, -.03, .10, .20, 9), (.15, -.03, .19, .14, 7), (.31, -.03, .295, .21, 9), (.46, -.03, .50, .18, 8), (.93, -.03, .90, .22, 9)]
    cross = [(.640, .24, .520, .32, 9), (.645, .44, .555, .50, 8), (.800, .36, .900, .44, 9), (.800, .56, .870, .60, 6)]
    return grove(58, trees, far, mid, near, hang, cross)


def variant_c() -> np.ndarray:
    """Ferns first. A lower view. Near ferns fill the bottom third. Three large trunks rise behind them, the rest step back."""
    trees = [(.150, .09, 1.0, 0), (.232, .16, 1.1, 0), (.330, .07, .9, 0), (.612, .15, 1.1, 0), (.690, .08, .9, 0), (.775, .18, 1.1, 0), (.860, .10, 1.0, 0),
             (.090, .48, 1.0, .003), (.420, .40, .95, -.003), (.560, .52, 1.05, .003), (.930, .44, 1.0, -.003),
             (.275, .80, 1.1, .008), (.480, .92, 1.2, -.004), (.800, .76, 1.0, -.007)]
    far = [(x, .685 + .012 * (i % 3), .07, 6) for i, x in enumerate(np.linspace(.04, .98, 14))]
    mid = [(.04, .80, .12, 7), (.16, .82, .13, 8), (.37, .80, .12, 7), (.64, .82, .13, 8), (.72, .79, .11, 7), (.90, .82, .13, 8)]
    near = [(.04, .93, .27, 10), (.19, .96, .25, 10), (.36, .94, .29, 11), (.55, .96, .26, 10), (.70, .93, .29, 11), (.87, .95, .27, 10), (1.0, .94, .24, 9)]
    hang = [(.06, -.03, .04, .19, 9), (.38, -.03, .40, .17, 8), (.64, -.03, .615, .21, 9), (.90, -.03, .93, .17, 8)]
    cross = [(.345, .26, .440, .33, 9), (.555, .40, .660, .46, 9), (.745, .32, .665, .38, 8), (.340, .50, .410, .54, 6)]
    return grove(59, trees, far, mid, near, hang, cross)


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/redwoods-{k}-value.png"); print("painted", k)
