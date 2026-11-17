"""Meadow scene. Three hand-placed compositions. Run: python3 meadow.py <out_dir> [a b c]

Not in the brief's list of five and not approved by the owner. Variants for the scene gate only.
"""
from __future__ import annotations

import sys
import numpy as np
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise
from lake import sky, treeline
from mountains import ridge, haze

XX = XN * W
YP = YN * H


def crown_tree(p, x, base, height, spread, density, seed, above=1.0):
    """One flat-crowned tree: a thin leaning trunk and a wide, shallow canopy with an uneven underside."""
    top = base - height
    lean = 0.012 * ((seed % 5) - 2) / 2
    t = np.clip((base - YN) / max(height, 1e-6), 0, 1)
    trunk = (0.0035 * W * (1.0 - 0.45 * t)) - np.abs(XX - (x + lean * t) * W)          # signed, in pixels
    trunk = np.where((YN > top + 0.3 * height * 0.2) & (YN < base + 0.004), trunk, -9.0)
    rx, ry = spread * W, height * 0.30 * H
    cx, cy = (x + lean) * W, (top + height * 0.22) * H
    under = 1.0 + 0.5 * smoothstep(0.0, 1.0, (YP - cy) / ry)                           # flatter and wider underneath
    canopy = (1.0 - np.sqrt(((XX - cx) / (rx * under)) ** 2 + ((YP - cy) / ry) ** 2)) * ry
    m = np.maximum(p.ragged(trunk, edge=0.8, rough=1.5, fine=1.5, seed=seed) * (trunk > -4),
                   p.ragged(canopy, edge=1.6, rough=3.5, fine=2.5, tooth=1.5, seed=seed + 1) * (canopy > -7)) * above   # no stray specks: a speck in the sky reads as a bird
    p.wash(m, density, rim=0.22, rim_w=3, gran=0.075, flow=0.2, seed=seed + 2)


def swathes(p, y0, y1, n, seed, strength=0.24):
    """Light lying on grass: long, soft, slightly tilted bands of paper kept between y0 and y1."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        cy = y0 + (y1 - y0) * (i + 0.5 + 0.3 * (rng.random() - 0.5)) / n
        tilt = 0.03 * (rng.random() - 0.5); cx = 0.2 + 0.6 * rng.random(); half = 0.25 + 0.3 * rng.random()
        hh = 0.020 + 0.016 * (i / max(n - 1, 1))
        band = np.exp(-((YN - (cy + tilt * (XN - 0.5))) / hh) ** 2) * np.exp(-((XN - cx) / half) ** 4)
        p.lift(strength * band * (0.6 + 0.4 * smoothstep(-1, 1, noise(seed + 7 * i, 3.0, sigma_x=60.0))))


def grass(p, pts, density, seed, fade=None, tooth=2.2):
    """A swell of grassland. Its top edge is fine and broken, like seed heads against the light."""
    prof = p.profile(pts, wobble=0.0025, wobble_sigma=9, seed=seed)
    m = p.ragged(p.below(prof), edge=1.2, rough=2.0, fine=4.0, tooth=tooth, seed=seed + 1)
    d = density if fade is None else density - fade[0] * smoothstep(fade[1], fade[2], YN)
    p.wash(m, d, rim=0.18, rim_w=3, gran=0.085, flow=0.26, flow_sigma=30, flow_aspect=6.0, seed=seed + 2)
    return prof


def variant_a() -> np.ndarray:
    """Open plain. A low horizon and a wide sky. Far pale hills, a loose line of flat-crowned trees, three swells of grass."""
    p = Painting(paper_seed=27)
    above = np.ones_like(YN)
    sky(p, above, top=0.30, reach=0.52, seed=611)
    ridge(p, [(-0.05, .60), (.14, .575), (.30, .59), (.46, .605), (.62, .585), (.80, .57), (1.05, .60)],
          0.20, above, 621, edge=2.4, fade=(0.10, 0.56, 0.66))
    haze(p, 0.635, 0.01, 0.028, 0.55, 626)
    grass(p, [(-0.05, .665), (.2, .655), (.45, .66), (.7, .668), (1.05, .655)], 0.34, 631, fade=(0.10, 0.66, 0.80))
    for i, (x, h, s) in enumerate([(.565, .155, .050), (.640, .200, .066), (.705, .130, .042), (.800, .170, .056), (.905, .105, .036)]):
        crown_tree(p, x, 0.668, h, s, 0.62 + 0.05 * (i % 2), 640 + 9 * i)
    grass(p, [(-0.05, .76), (.18, .745), (.40, .77), (.62, .80), (.84, .775), (1.05, .76)], 0.50, 661, fade=(0.14, 0.76, 0.92))
    swathes(p, 0.70, 0.86, 3, 671)
    grass(p, [(-0.05, .90), (.22, .93), (.46, .905), (.70, .885), (1.05, .915)], 0.80, 681)
    return p.finish()


def variant_b() -> np.ndarray:
    """Slope. One long gentle slope from upper left to lower right, a dark hedge of wood behind it, one tree on the brow."""
    p = Painting(paper_seed=28)
    above = np.ones_like(YN)
    sky(p, above, top=0.28, reach=0.50, seed=711)
    ridge(p, [(-0.05, .52), (.2, .50), (.42, .535), (.62, .56), (.82, .545), (1.05, .53)], 0.22, above, 721, edge=2.4,
          fade=(0.10, 0.50, 0.62))
    haze(p, 0.60, -0.02, 0.03, 0.5, 726)
    wood = p.profile([(-0.05, .47), (.08, .485), (.20, .52), (.32, .57), (.42, .625), (.50, .69), (1.05, 1.1)],
                     wobble=0.003, wobble_sigma=10, seed=731)
    wood = treeline(wood, [(.03, .05, .0060), (.075, .03, .0045), (.13, .045, .0056), (.19, .028, .0042)], canopy=0.02, seed=7)
    m = p.ragged(p.below(wood), edge=1.4, rough=3, fine=3, tooth=1.6, seed=732)
    p.wash(m, 0.66, rim=0.25, rim_w=4, gran=0.08, flow=0.22, seed=733)
    grass(p, [(-0.05, .56), (.15, .585), (.35, .64), (.55, .70), (.75, .745), (1.05, .78)], 0.40, 741, fade=(0.12, 0.60, 0.84))
    crown_tree(p, .665, 0.735, .26, .085, 0.70, 751)
    swathes(p, 0.70, 0.84, 2, 761, strength=0.22)
    grass(p, [(-0.05, .80), (.25, .84), (.5, .88), (.75, .90), (1.05, .93)], 0.74, 771)
    return p.finish()


def seg_field(x0, y0, x1, y1, w0, w1):
    """Signed field in pixels for one tapered stroke from (x0, y0) to (x1, y1), normalised ends, widths in pixels."""
    ax, ay, bx, by = x0 * W, y0 * H, x1 * W, y1 * H
    dx, dy = bx - ax, by - ay; L2 = dx * dx + dy * dy
    t = np.clip(((XX - ax) * dx + (YP - ay) * dy) / L2, 0, 1)
    d = np.hypot(XX - (ax + t * dx), YP - (ay + t * dy))
    return (w0 + (w1 - w0) * t) - d


def copse(p, cx, base, width, height, density, seed):
    """One stand of trees as a single low mass of uneven domes, wider than tall, seated on the ground.

    No trunks show. A rounded mass on legs reads as an animal, which invariant 7 rules out.
    """
    f = np.full((H, W), -99.0)
    for dx, top, rx in [(-0.44, 0.50, 0.16), (-0.27, 0.78, 0.20), (-0.04, 1.00, 0.24), (0.20, 0.70, 0.19), (0.36, 0.86, 0.17), (0.50, 0.42, 0.13)]:
        ex, ey = (cx + dx * width) * W, base * H
        rxp, ryp = rx * width * W, top * height * H
        f = np.maximum(f, (1.0 - np.sqrt(((XX - ex) / rxp) ** 2 + ((YP - ey) / ryp) ** 2)) * min(rxp, ryp))
    m = p.ragged(f, edge=1.6, rough=3.0, fine=2.5, tooth=1.4, seed=seed) * (f > -6) * smoothstep(base + 0.004, base - 0.004, YN)
    p.wash(m, density, rim=0.22, rim_w=3, gran=0.075, flow=0.2, seed=seed + 5)
    p.wash(m * smoothstep(base - height * 0.45, base, YN), 0.30, rim=0, gran=0.06, flow=0.2, seed=seed + 6)   # darker toward the ground


def swell(p, pts, density, seed, fade, soft):
    """A swell of grass whose upper edge melts into the wash behind it. soft is the edge softness in pixels."""
    prof = p.profile(pts, wobble=0.002, wobble_sigma=14, seed=seed)
    m = p.ragged(p.below(prof), edge=soft, rough=1.6, fine=1.6, tooth=0.9, seed=seed + 1)
    d = density - fade[0] * smoothstep(fade[1], fade[2], YN)
    p.wash(m, d, rim=0.0, gran=0.085, flow=0.26, flow_sigma=30, flow_aspect=6.0, seed=seed + 2)
    return prof


def blades(p, prof, n, seed, density=0.78, width=0.0024, length=(0.030, 0.045), clump=0.0):
    """Short tapered blades of grass along one crest, all leaning at 56 degrees, uneven in length and spacing."""
    rng = np.random.default_rng(seed); ang = np.radians(56.0)
    f = np.full((H, W), -99.0)
    for i in range(n):
        x = (i + rng.random()) / n
        if rng.random() < 0.22: continue                                   # gaps, so the crest is not a comb
        if clump and np.sin(x * 40.0 + 3.0 * np.sin(x * 9.0)) < clump: continue    # blades stand in tufts with bare sand between
        px = int(np.clip(x * W, 0, W - 1)); y = prof[px] / H + 0.006
        ln = (length[0] + length[1] * rng.random()) * H
        x1, y1 = x + ln * np.cos(ang) / W, y - ln * np.sin(ang) / H
        f = np.maximum(f, seg_field(x, y, x1, y1, width * W * (0.7 + 0.6 * rng.random()), 0.3))
    m = p.ragged(f, edge=0.9, rough=1.0, fine=1.0, seed=seed + 1) * (f > -3)
    p.wash(m, density, rim=0.0, gran=0.06, flow=0.1, seed=seed + 2)


def variant_c() -> np.ndarray:
    """Tall grass. A high horizon. The viewer stands in the meadow: long swells of grass cross each other, with one copse far off."""
    p = Painting(paper_seed=29)
    above = np.ones_like(YN)
    sky(p, above, top=0.24, reach=0.34, seed=811)
    ridge(p, [(-0.05, .36), (.2, .345), (.45, .37), (.7, .35), (1.05, .365)], 0.18, above, 821, edge=2.4, fade=(0.08, 0.34, 0.44))
    haze(p, 0.405, 0.015, 0.026, 0.5, 826)
    # long shallow S-curves that cross: each swell is thin where it runs out and deep where it comes near
    copse(p, 0.700, 0.446, 0.200, 0.115, 0.50, 841)            # painted before the first swell, so the grass hides the trunks: a mass on legs reads as an animal
    swell(p, [(-0.05, .455), (.22, .437), (.48, .428), (.74, .437), (1.05, .452)], 0.26, 831, (0.08, 0.44, 0.58), 5.0)
    swell(p, [(-0.05, .50), (.20, .525), (.42, .565), (.64, .585), (.84, .565), (1.05, .525)], 0.36, 851, (0.10, 0.54, 0.72), 6.0)
    swell(p, [(-0.05, .70), (.18, .665), (.40, .625), (.60, .63), (.80, .675), (1.05, .735)], 0.48, 861, (0.12, 0.66, 0.84), 6.0)
    swathes(p, 0.585, 0.62, 1, 866, strength=0.16)
    swell(p, [(-0.05, .775), (.22, .805), (.46, .845), (.68, .835), (.86, .79), (1.05, .745)], 0.62, 871, (0.10, 0.80, 0.95), 5.0)
    near = swell(p, [(-0.05, .93), (.20, .905), (.44, .895), (.70, .925), (1.05, .965)], 0.84, 881, (0.0, 0.9, 1.0), 2.2)
    blades(p, near, 64, 891)
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/meadow-{k}-value.png"); print("painted", k)
