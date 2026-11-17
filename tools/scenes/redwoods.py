"""Redwoods scene. Three hand-placed compositions. Run: python3 redwoods.py <out_dir> [a b c]

Not approved by the owner. Variants for the scene gate only.
What failed before (docs/spec.md): trunks in a row read as a barcode; a corridor with drooping boughs was eerie;
round dabs read as camouflage; sticks with needle lines read as sickly pines. Wanted: tall trunks, a canopy,
a pine-needle feel, calm, not muddy, not eerie.
"""
from __future__ import annotations

import sys
import numpy as np
from scipy import ndimage as ndi
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise
from lake import sky
from mountains import ridge, haze
from meadow import blades, swell, seg_field, XX, YP


def giants(prof, trees, seed):
    """Raise a skyline of very tall conifers from a ground profile.

    Each tree is a column, not a cone: straight flanks, rounded shoulders, a short leader, and boughs in uneven tiers.
    trees: (x, height, half_width), normalised. Heights and spacing are placed by hand and are never even.
    """
    rng = np.random.default_rng(seed)
    x = np.arange(W) / W
    up = np.zeros(W)
    tier = ndi.gaussian_filter1d(rng.standard_normal(W), 2.6); tier /= tier.std()
    for i, (tx, th, tw) in enumerate(trees):
        u = np.abs(x - tx) / tw
        body = np.clip(1.0 - u ** 2.6, 0, 1) ** 0.55                            # a column with rounded shoulders
        leader = 0.10 * np.clip(1.0 - u / 0.22, 0, 1)                           # a short tip
        flank = 1.0 + 0.11 * np.clip(tier, -1.4, 1.4) * smoothstep(0.25, 0.9, u)  # tiers of boughs notch the flanks
        up = np.maximum(up, th * (body * flank + leader) * (u < 1.0))
    return prof - up * H


def trunk(p, x, base, top, half, density, seed, lean=0.0, flare=0.55, bark=0.22):
    """One trunk: wide, slightly tapered, flared where it meets the ground, with long soft furrows of bark."""
    t = np.clip((base - YN) / max(base - top, 1e-6), 0, 1.2)
    hw = half * W * (1.0 - 0.16 * t) * (1.0 + flare * np.exp(-np.clip(base - YN, 0, 1) / 0.045))
    cx = (x + lean * t) * W
    f = hw - np.abs(XX - cx)
    f = np.where(YN <= base + 0.01, f, -9.0)
    m = p.ragged(f, edge=1.6, rough=2.0, fine=2.0, tooth=1.2, seed=seed) * (f > -5)
    side = smoothstep(-1.0, 1.0, (XX - cx) / np.maximum(hw, 1.0))               # the side away from the light is deeper
    p.wash(m, density * (0.78 + 0.22 * side), rim=0.20, rim_w=4, gran=0.07, flow=0.10, seed=seed + 1)
    rng = np.random.default_rng(seed + 2)
    n = ndi.gaussian_filter1d(rng.standard_normal(W), 5.0); n /= n.std()
    furrow = smoothstep(0.35, 1.1, n[np.clip((XX - cx + 0.5 * W).astype(int), 0, W - 1)])
    p.lift(bark * furrow * m * smoothstep(0.0, 0.5, 1.0 - np.abs(XX - cx) / np.maximum(hw, 1.0)))
    return m


def floor(p, pts, density, seed, fade=(0.0, 0.9, 1.0)):
    return swell(p, pts, density, seed, fade, 2.6)


def bough(p, x0, y0, x1, y1, n, seed, density=0.6, needle=0.030, width=0.0012):
    """One bough that leaves a trunk: a thin tapered branch carrying a flat spray of short needles.

    Needles all lie on the 56 degree line, above and below the branch, and are longest in the middle of the spray.
    Every bough starts on a trunk. Needles attached to nothing read as a sickly pine.
    """
    rng = np.random.default_rng(seed); ang = np.radians(56.0)
    f = seg_field(x0, y0, x1, y1, 0.0026 * W, 0.0008 * W)
    for i in range(n):
        t = (i + 0.3 + 0.6 * rng.random()) / n
        if t < 0.10: continue
        bx, by = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        ln = needle * H * (0.45 + 0.75 * np.sin(np.pi * min(t * 1.1, 1.0))) * (0.8 + 0.4 * rng.random())
        s = 1.0 if i % 2 == 0 else -1.0
        f = np.maximum(f, seg_field(bx, by, bx + s * ln * np.cos(ang) / W, by - s * ln * np.sin(ang) / H, width * W, 0.3))
    # the spray is a flat pad of foliage first, and the needles are its edge
    dx, dy = (x1 - x0) * W, (y1 - y0) * H; L = np.hypot(dx, dy)
    along = ((XX - x0 * W) * dx + (YP - y0 * H) * dy) / L
    across = ((XX - x0 * W) * dy - (YP - y0 * H) * dx) / L
    t = np.clip(along / L, 0, 1)
    half = needle * H * 0.62 * np.sin(np.pi * np.clip(t * 1.05, 0, 1)) ** 0.7
    pad = np.where((along > 0.10 * L) & (along < 1.04 * L), half - np.abs(across + 0.25 * half), -9.0)
    pm = p.ragged(pad, edge=2.0, rough=2.5, fine=2.0, tooth=1.6, seed=seed + 3) * (pad > -5)
    p.wash(pm, density * 0.62, rim=0.15, rim_w=3, gran=0.08, flow=0.2, seed=seed + 4)
    m = p.ragged(f, edge=0.9, rough=1.0, fine=1.0, seed=seed + 1) * (f > -3)
    p.wash(m, density, rim=0.0, gran=0.06, flow=0.1, seed=seed + 2)


def spray(f, x0, y0, x1, y1, n, needle, width, rng):
    """One twig with needles in two ranks, as a redwood carries them. Adds to the field f and returns it."""
    f = np.maximum(f, seg_field(x0, y0, x1, y1, 0.0020 * W, 0.0007 * W))
    dx, dy = (x1 - x0) * W, (y1 - y0) * H; L = np.hypot(dx, dy); ux, uy = dx / L, dy / L
    for i in range(n):
        t = (i + 0.5) / n
        bx, by = x0 * W + dx * t, y0 * H + dy * t
        ln = needle * H * (0.55 + 0.6 * np.sin(np.pi * t)) * (0.85 + 0.3 * rng.random())
        for sgn in (1.0, -1.0):                                   # needles lean toward the tip of the twig
            ex, ey = bx + ln * (0.55 * ux - sgn * 0.83 * uy), by + ln * (0.55 * uy + sgn * 0.83 * ux)
            f = np.maximum(f, seg_field(bx / W, by / H, ex / W, ey / H, width * W, 0.3))
    return f


def framing_branch(p, pts, twigs, seed, density=0.86, needle=0.050, width=0.0016):
    """A branch close to the viewer that enters from the edge of the card. pts: the main stem. twigs: (t along stem, dx, dy, n)."""
    rng = np.random.default_rng(seed)
    f = np.full((H, W), -99.0)
    for (xa, ya), (xb, yb) in zip(pts[:-1], pts[1:]):
        f = np.maximum(f, seg_field(xa, ya, xb, yb, 0.0034 * W, 0.0022 * W))
    xs, ys = np.array([q[0] for q in pts]), np.array([q[1] for q in pts]); tt = np.linspace(0, 1, len(pts))
    for t, dx, dy, n in twigs:
        x0, y0 = np.interp(t, tt, xs), np.interp(t, tt, ys)
        f = spray(f, x0, y0, x0 + dx, y0 + dy, n, needle, width, rng)
    m = p.ragged(f, edge=0.9, rough=1.0, fine=1.0, seed=seed + 1) * (f > -3)
    p.wash(m, density, rim=0.0, gran=0.06, flow=0.1, seed=seed + 2)


def wall(p, base, tips, density, seed, cut):
    """A far wall of forest: one mass with an uneven top and narrow tips, as the Lake's wood is painted."""
    from lake import treeline
    prof = p.profile(base, wobble=0.003, wobble_sigma=16, seed=seed)
    prof = treeline(prof, tips, canopy=0.020, seed=seed % 7)
    m = p.ragged(p.below(prof), edge=2.0, rough=3, fine=2.5, seed=seed + 1) * smoothstep(cut + 0.01, cut - 0.01, YN)
    p.wash(m, density, rim=0.2, rim_w=4, gran=0.06, flow=0.14, seed=seed + 2)


def variant_a() -> np.ndarray:
    """Two giants. A giant trunk at each side, cut off by the card, of different widths. Between them pale trunks stand in mist."""
    p = Painting(paper_seed=47)
    above = np.ones_like(YN)
    sky(p, above, top=0.14, reach=0.9, seed=1211)
    for i, (x, hw, d) in enumerate([(.300, .013, .15), (.415, .019, .20), (.520, .011, .14), (.640, .017, .19), (.745, .012, .15)]):
        trunk(p, x, 0.72 + 0.01 * (i % 2), -0.2, hw, d, 1220 + 7 * i, flare=0.3, bark=0.08)
    haze(p, 0.64, 0.01, 0.08, 0.6, 1256)
    floor(p, [(-0.05, .75), (.3, .735), (.6, .755), (1.05, .74)], 0.28, 1261, (0.08, 0.75, 0.9))
    trunk(p, .575, 0.80, -0.2, .030, 0.44, 1271, lean=-0.005)
    floor(p, [(-0.05, .86), (.25, .845), (.5, .865), (.8, .85), (1.05, .865)], 0.44, 1281, (0.08, 0.86, 0.98))
    trunk(p, .925, 0.92, -0.2, .060, 0.74, 1291, lean=-0.008, flare=0.65, bark=0.24)
    trunk(p, .115, 0.94, -0.2, .092, 0.86, 1301, lean=0.010, flare=0.7, bark=0.26)
    g2 = floor(p, [(-0.05, .955), (.3, .94), (.62, .925), (.85, .945), (1.05, .93)], 0.70, 1311)
    blades(p, g2, 150, 1316, density=0.6, width=0.0015, length=(0.03, 0.04), clump=-0.2)
    return p.finish()


def variant_b() -> np.ndarray:
    """Among the trunks. One giant, close and off centre. Four more of very different widths step back into mist. Ferns on the floor."""
    p = Painting(paper_seed=48)
    above = np.ones_like(YN)
    sky(p, above, top=0.14, reach=0.9, seed=1311)
    for i, (x, hw, d) in enumerate([(.335, .018, .17), (.585, .012, .14), (.660, .015, .16), (.905, .022, .20)]):
        trunk(p, x, 0.73, -0.2, hw, d, 1330 + 7 * i, flare=0.3, bark=0.08)
    haze(p, 0.66, 0.01, 0.07, 0.55, 1356)
    floor(p, [(-0.05, .76), (.3, .745), (.6, .77), (1.05, .75)], 0.30, 1361, (0.08, 0.76, 0.9))
    trunk(p, .480, 0.80, -0.2, .030, 0.46, 1371, lean=0.006)
    trunk(p, .775, 0.83, -0.2, .048, 0.58, 1381, lean=-0.008)
    floor(p, [(-0.05, .86), (.25, .84), (.5, .865), (.8, .85), (1.05, .87)], 0.46, 1391, (0.08, 0.86, 0.98))
    trunk(p, .165, 0.93, -0.2, .088, 0.84, 1401, lean=0.010, flare=0.7, bark=0.26)
    framing_branch(p, [(1.03, .04), (.93, .10), (.84, .19), (.77, .31)],
                   [(.18, -.085, .010, 13), (.36, -.020, .115, 12), (.55, -.100, .030, 14), (.74, -.010, .120, 11), (1.0, -.060, .085, 12)], 1421)
    g2 = floor(p, [(-0.05, .955), (.3, .94), (.62, .925), (.85, .945), (1.05, .93)], 0.70, 1411)
    blades(p, g2, 150, 1416, density=0.6, width=0.0015, length=(0.03, 0.04), clump=-0.2)
    return p.finish()


def variant_c() -> np.ndarray:
    """The edge of the grove. One giant trunk and two neighbours on the left. To the right, open ground and a far wall of forest."""
    p = Painting(paper_seed=49)
    above = np.ones_like(YN)
    sky(p, above, top=0.24, reach=0.46, seed=1511)
    wall(p, [(-0.05, .56), (.3, .55), (.6, .57), (1.05, .55)],
         [(.45, .07, .016), (.53, .11, .020), (.63, .08, .017), (.74, .12, .021), (.85, .08, .017), (.95, .10, .019)], 0.32, 1521, 0.77)
    haze(p, 0.71, 0.0, 0.04, 0.55, 1526)
    floor(p, [(-0.05, .76), (.3, .75), (.6, .765), (1.05, .755)], 0.30, 1531, (0.08, 0.76, 0.92))
    trunk(p, .345, 0.80, -0.2, .020, 0.40, 1541, lean=0.004, flare=0.4, bark=0.14)
    trunk(p, .262, 0.83, -0.2, .034, 0.56, 1551, lean=-0.006)
    floor(p, [(-0.05, .87), (.2, .855), (.45, .875), (.75, .86), (1.05, .875)], 0.46, 1561, (0.08, 0.87, 0.98))
    trunk(p, .105, 0.94, -0.2, .082, 0.86, 1571, lean=0.008, flare=0.7, bark=0.26)
    framing_branch(p, [(1.03, .06), (.92, .11), (.82, .19), (.74, .30)],
                   [(.16, -.090, .005, 13), (.36, -.015, .115, 12), (.56, -.105, .035, 14), (.76, -.005, .120, 11), (1.0, -.065, .090, 12)], 1591)
    g2 = floor(p, [(-0.05, .955), (.3, .94), (.6, .93), (1.05, .95)], 0.70, 1581)
    blades(p, g2, 150, 1586, density=0.6, width=0.0015, length=(0.03, 0.04), clump=-0.2)
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/redwoods-{k}-value.png"); print("painted", k)
