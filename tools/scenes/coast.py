"""Coast scene. Three hand-placed compositions. Run: python3 coast.py <out_dir> [a b c]

Not approved by the owner. Variants for the scene gate only. The sea is open: no far shore, so it is not the Lake.
"""
from __future__ import annotations

import sys
import numpy as np
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise
from lake import sky
from mountains import ridge, haze
from meadow import blades, swell, XX, YP


def sea(p, yh, shore, far, near, seed, keep=1.0):
    """Open water from the horizon down to the shore line. Deepest at the horizon, pale where it thins over sand."""
    m = smoothstep(yh - 0.002, yh + 0.004, YN) * smoothstep(2.0, -2.0, YP - shore[None, :]) * keep
    depth = np.clip((shore[None, :] / H - YN) / np.maximum(shore[None, :] / H - yh, 1e-3), 0, 1)     # 1 at the horizon, 0 at the shore
    p.wash(m, near + (far - near) * depth ** 0.8, rim=0, gran=0.05, flow=0.16, flow_sigma=24, flow_aspect=9.0, seed=seed)
    p.lift(0.5 * np.exp(-((YN - (yh + 0.006)) / 0.004) ** 2) * smoothstep(-0.3, 0.6, noise(seed + 1, 3.0, sigma_x=90.0)) * m)   # a broken line of light under the horizon
    haze(p, yh + 0.002, 0.0, 0.013, 0.5, seed + 5)                           # paper mist over the horizon, so it is not a ruled line
    return m


def foam(p, shore, offsets, seed, strength=0.8, keep=1.0):
    """Lines of foam: each follows the shore at its own distance, broken and uneven in width. They are still, not breaking."""
    for i, (off, thick, g) in enumerate(offsets):                       # g: how broken the line is. Far lines are short and thin, near ones wider and softer
        wob = 0.006 * noise(seed + 3 * i, 3.0, sigma_x=70.0)[H // 2][None, :]
        d = YN - (shore[None, :] / H - off + wob)
        gaps = smoothstep(g - 0.4, g + 0.4, noise(seed + 3 * i + 1, 3.0, sigma_x=45.0))
        p.lift(strength * np.exp(-(d / thick) ** 2) * gaps * keep)


def sand(p, shore, density, seed, wet=0.035):
    """Beach below the shore line: a pale wash, darker and smoother where it is wet at the water's edge."""
    m = p.ragged(p.below(shore), edge=3.0, rough=2.0, fine=2.0, tooth=0.8, seed=seed)
    p.wash(m, density, rim=0.0, gran=0.09, flow=0.2, flow_sigma=40, flow_aspect=5.0, seed=seed + 1)
    band = np.exp(-(((YN - shore[None, :] / H) - wet * 0.6) / wet) ** 2) * m
    p.wash(band, 0.07, rim=0, gran=0.04, flow=0.1, seed=seed + 2)          # faint: a dark line under the foam reads as a breaking wave
    return m


def headland(p, pts, density, seed, yh, fade=0.0):
    prof = p.profile(pts, wobble=0.004, wobble_sigma=9, seed=seed)
    m = p.ragged(p.below(prof), edge=1.8, rough=1.4, fine=1.4, tooth=0.9, seed=seed + 1) * smoothstep(yh + 0.012, yh + 0.004, YN)   # one long profile, not bubbled dabs
    p.wash(m, density - fade * smoothstep(yh - 0.15, yh, YN), rim=0.28, rim_w=4, gran=0.075, flow=0.07, seed=seed + 2)
    return prof


def variant_a() -> np.ndarray:
    """Open sea. A level horizon, a wide sky, three lines of foam and a pale beach that curves in from the lower left."""
    p = Painting(paper_seed=37)
    yh = 0.44
    above = smoothstep(yh + 0.003, yh - 0.003, YN)
    sky(p, above, top=0.30, reach=0.44, seed=911)
    shore = p.profile([(-0.05, .76), (.15, .775), (.35, .80), (.55, .84), (.75, .885), (.92, .93), (1.05, .965)],
                      wobble=0.003, wobble_sigma=20, seed=921)
    sea(p, yh, shore, far=0.62, near=0.10, seed=931)
    foam(p, shore, [(0.010, 0.009, -0.5), (0.065, 0.007, -0.2), (0.150, 0.005, 0.1), (0.240, 0.0035, 0.4)], 941)
    sand(p, shore, 0.16, 951)
    return p.finish()


def variant_b() -> np.ndarray:
    """Headlands. Two headlands step down into the sea from the right, the nearer one dark. Open water to the left."""
    p = Painting(paper_seed=38)
    yh = 0.52
    above = smoothstep(yh + 0.003, yh - 0.003, YN)
    sky(p, above, top=0.30, reach=0.48, seed=1011)
    shore = p.profile([(-0.05, .90), (.25, .915), (.5, .94), (.75, .975), (1.05, 1.02)], wobble=0.003, wobble_sigma=20, seed=1021)
    headland(p, [(-0.05, 1.2), (.50, yh + .05), (.54, yh - .004), (.60, .47), (.68, .44), (.80, .425), (1.05, .41)],
             0.34, 1031, yh, fade=0.12)
    haze(p, yh - 0.02, 0.0, 0.03, 0.5, 1036)
    pts = [(-0.05, 1.3), (.60, yh + .44), (.66, yh + .30), (.705, yh + .14), (.74, yh + .01), (.78, .43), (.84, .335), (.91, .28), (1.05, .235)]
    open_water = smoothstep(3.0, -3.0, p.below(p.profile(pts, wobble=0.004, wobble_sigma=9, seed=1051)) - 10.0)   # the sea is not painted under the near headland
    sea(p, yh, shore, far=0.58, near=0.12, seed=1041, keep=open_water)
    near = headland(p, pts, 0.82, 1051, 2.0)
    foam(p, shore, [(0.012, 0.009, -0.5), (0.090, 0.0065, -0.1), (0.200, 0.004, 0.3), (0.300, 0.003, 0.5)], 1061, keep=open_water)
    sand(p, shore, 0.16, 1071)
    return p.finish()


def variant_c() -> np.ndarray:
    """Dunes. The viewer stands in the dunes. Two pale dunes with grass on their crests, a strip of sea, a low horizon."""
    p = Painting(paper_seed=39)
    yh = 0.50
    above = smoothstep(yh + 0.003, yh - 0.003, YN)
    sky(p, above, top=0.28, reach=0.50, seed=1111)
    shore = p.profile([(-0.05, .64), (.3, .65), (.6, .665), (1.05, .68)], wobble=0.002, wobble_sigma=20, seed=1121)
    sea(p, yh, shore, far=0.60, near=0.16, seed=1131)
    foam(p, shore, [(0.008, 0.005, -0.4), (0.050, 0.004, 0.1)], 1141)
    sand(p, shore, 0.12, 1151, wet=0.02)
    d1 = swell(p, [(-0.05, .80), (.15, .76), (.32, .715), (.48, .70), (.64, .735), (.82, .80), (1.05, .86)], 0.26, 1161, (0.06, 0.74, 0.92), 3.0)
    blades(p, d1, 190, 1166, density=0.34, width=0.0011, length=(0.022, 0.030), clump=0.1)
    d2 = swell(p, [(-0.05, .955), (.2, .93), (.42, .90), (.62, .855), (.80, .80), (.93, .775), (1.05, .78)], 0.42, 1171, (0.0, 0.9, 1.0), 2.4)
    blades(p, d2, 170, 1176, density=0.55, width=0.0013, length=(0.030, 0.040), clump=0.0)
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/coast-{k}-value.png"); print("painted", k)
