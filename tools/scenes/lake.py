"""Lake scene. Three hand-placed compositions. Run: python3 lake.py <out_dir> [a b c]"""
from __future__ import annotations

import sys
import numpy as np
from paint import Painting, XN, YN, H, W, smoothstep, save_value


def treeline(prof: np.ndarray, tips, canopy: float = 0.012, seed: int = 0) -> np.ndarray:
    """Turn a ridge profile into the top of a conifer wood.

    The wood is one mass. Its top is uneven at two scales, and a few hand-placed
    tips of different heights stand above it. tips: (x, height, half_width), normalised.
    """
    from scipy import ndimage as ndi
    rng = np.random.default_rng(900 + seed)
    x = np.arange(W) / W
    # uneven canopy: small crowns, sharpened so they read as tree tops and not as waves
    n1 = ndi.gaussian_filter1d(rng.standard_normal(W), 7.0); n1 /= n1.std()
    n2 = ndi.gaussian_filter1d(rng.standard_normal(W), 22.0); n2 /= n2.std()
    crowns = canopy * (0.75 * np.clip(n1, -0.3, 2.2) ** 1.0 + 0.6 * n2)
    up = np.zeros(W)
    for i, (tx, th, tw) in enumerate(tips):
        lean = 1.0 + 0.3 * (((i * 37) % 5) - 2) / 2.0
        u = np.where(x < tx, (tx - x) / (tw * lean), (x - tx) / (tw / lean))
        e = 1.0 + 0.05 * ((i * 53) % 4)                         # straight sides, never bulging
        up = np.maximum(up, th * np.clip(1 - u, 0, 1) ** e)
    # boughs: the flanks of each tip are notched, more toward the base
    hf = ndi.gaussian_filter1d(rng.standard_normal(W), 2.2); hf /= hf.std()
    up = up * (1.0 + 0.20 * np.clip(hf, -1.5, 1.5))
    # the mass only grows crowns where the wood stands, set by the caller through the tips' span
    return prof - (up + crowns) * H


def sky(p: Painting, above: np.ndarray, top: float, reach: float, seed: int) -> None:
    """Graded wash: densest at the top edge, bare paper before the ridge line."""
    d = top * (1 - smoothstep(0.0, reach, YN)) ** 1.4
    p.wash(above, d, rim=0, gran=0.032, flow=0.10, flow_sigma=90, flow_aspect=3.0, bloom=0.05, seed=seed)


def water(p: Painting, yw: float, land: np.ndarray, near: float, far: float, seed: int,
          strength: float = 0.80, squash: float = 0.86) -> None:
    """Pale at the far shore, deeper toward the viewer. A broken line of bare paper is kept under the shore."""
    below = smoothstep(yw + 0.002, yw + 0.008, YN)
    d = far + (near - far) * smoothstep(yw, 1.0, YN) ** 1.5
    p.wash(below, d, rim=0, gran=0.040, flow=0.14, flow_sigma=22, flow_aspect=9.0, seed=seed)
    p.reflect(land, yw + 0.003, squash=squash, strength=strength, blur_y=4, shake=7, fade=0.55, seed=seed + 1)
    from paint import noise
    gaps = smoothstep(-0.4, 0.5, noise(seed + 2, 3.0, sigma_x=70.0))
    p.lift(0.75 * np.exp(-((YN - (yw + 0.011)) / 0.0055) ** 2) * gaps)


def ripples(p: Painting, lights, darks) -> None:
    for i, (cx, cy, hl, th, a) in enumerate(lights):
        p.stroke(cx, cy, hl, th, a, lift=True, wobble=0.002, seed=300 + i)
    for i, (cx, cy, hl, th, a) in enumerate(darks):
        p.stroke(cx, cy, hl, th, a, lift=False, wobble=0.002, seed=500 + i)


def variant_a() -> np.ndarray:
    """Fold. A far ridge with two summits, a slope from the right, a dark wooded point from the left."""
    p = Painting(paper_seed=7)
    yw = 0.535
    above = smoothstep(yw + 0.004, yw - 0.004, YN)
    sky(p, above, top=0.27, reach=0.40, seed=11)
    land0 = p.T.copy()

    far = p.profile([(-0.05, .405), (.08, .37), (.20, .275), (.27, .245), (.34, .30), (.45, .345),
                     (.55, .255), (.61, .225), (.70, .29), (.82, .36), (.94, .40), (1.05, .42)],
                    wobble=0.006, wobble_sigma=30, seed=21)
    m = p.ragged(p.below(far), edge=2.5, rough=4, fine=2, seed=22) * above
    p.wash(m, 0.30 - 0.20 * smoothstep(0.24, yw, YN), rim=0.22, rim_w=5, gran=0.064, flow=0.16, seed=23)
    p.mist(yw - 0.035, 0.055, 0.62, seed=24)

    mid = p.profile([(-0.05, yw + .30), (.26, yw + .12), (.33, yw + .03), (.40, .50), (.50, .455), (.62, .415),
                     (.74, .375), (.86, .385), (1.05, .33)], wobble=0.004, wobble_sigma=14, seed=31)
    m = p.ragged(p.below(mid), edge=1.6, rough=5, fine=3.5, seed=32) * above
    p.wash(m, 0.50 - 0.22 * smoothstep(0.36, yw, YN), rim=0.30, rim_w=5, gran=0.072, flow=0.2, seed=33)
    p.mist(yw - 0.012, 0.03, 0.40, seed=34, x_fade=smoothstep(0.30, 0.55, XN))

    near = p.profile([(-0.05, .345), (.05, .36), (.13, .395), (.21, .44), (.28, .485), (.335, .525),
                      (.36, yw + .03), (.44, yw + .12), (1.05, yw + .30)], wobble=0.003, wobble_sigma=10, seed=41)
    near = treeline(near, [(.018, .085, 0.0070), (.047, .045, 0.0049), (.070, .115, 0.0082), (.083, .070, 0.0061),
                           (.128, .060, 0.0057), (.163, .078, 0.0066), (.176, .040, 0.0045), (.232, .042, 0.0045),
                           (.286, .030, 0.0037)], canopy=0.013, seed=1)
    m = p.ragged(p.below(near), edge=1.3, rough=3, fine=3, tooth=1.6, seed=42) * above
    p.wash(m, 0.84, rim=0.25, rim_w=4, gran=0.080, flow=0.22, seed=43)
    p.wash(m * smoothstep(0.38, 0.50, YN), 0.45, rim=0, gran=0.056, flow=0.3, seed=44)

    land = p.T / np.maximum(land0, 1e-6)
    water(p, yw, land, near=0.24, far=0.04, seed=51)
    ripples(p,
        lights=[(.22, .590, .09, .0050, .60), (.57, .582, .13, .0045, .55), (.83, .600, .08, .0050, .50),
                (.36, .655, .11, .0065, .60), (.70, .640, .10, .0060, .50), (.13, .700, .08, .0075, .50),
                (.52, .745, .14, .0090, .55), (.85, .790, .10, .0090, .45), (.30, .850, .15, .0110, .50)],
        darks=[(.66, .710, .08, .0060, .22), (.42, .815, .10, .0080, .26), (.78, .895, .13, .0100, .30),
               (.24, .940, .15, .0110, .30), (.58, .960, .09, .0090, .26)])
    return p.finish()


def variant_b() -> np.ndarray:
    """Headland. Open water on the left, one dark wooded headland on the right, a low far shore."""
    p = Painting(paper_seed=8)
    yw = 0.60
    above = smoothstep(yw + 0.004, yw - 0.004, YN)
    sky(p, above, top=0.30, reach=0.46, seed=111)
    land0 = p.T.copy()

    far = p.profile([(-0.05, .500), (.10, .470), (.22, .425), (.33, .450), (.46, .492), (.60, .470),
                     (.74, .450), (1.05, .46)], wobble=0.005, wobble_sigma=26, seed=121)
    m = p.ragged(p.below(far), edge=2.5, rough=4, fine=2, seed=122) * above
    p.wash(m, 0.27 - 0.17 * smoothstep(0.42, yw, YN), rim=0.22, rim_w=5, gran=0.064, flow=0.16, seed=123)
    p.mist(yw - 0.03, 0.05, 0.60, seed=124)

    spit = p.profile([(-0.05, yw + .30), (.30, yw + .10), (.37, yw + .01), (.44, .565), (.52, .548), (.60, .556),
                      (.70, .54), (1.05, .52)], wobble=0.003, wobble_sigma=12, seed=131)
    m = p.ragged(p.below(spit), edge=1.6, rough=4, fine=3, seed=132) * above
    p.wash(m, 0.46, rim=0.30, rim_w=4, gran=0.072, flow=0.2, seed=133)

    head = p.profile([(-0.05, yw + .30), (.46, yw + .12), (.535, yw + .02), (.60, .535), (.66, .455), (.73, .37),
                      (.80, .30), (.88, .245), (.96, .215), (1.05, .20)], wobble=0.004, wobble_sigma=12, seed=141)
    head = treeline(head, [(.628, .050, 0.0049), (.655, .085, 0.0070), (.668, .045, 0.0045), (.722, .110, 0.0082),
                           (.741, .065, 0.0057), (.790, .090, 0.0074), (.842, .125, 0.0090), (.858, .070, 0.0061),
                           (.915, .080, 0.0070), (.962, .115, 0.0086), (.985, .060, 0.0057)], canopy=0.016, seed=2)
    m = p.ragged(p.below(head), edge=1.3, rough=3, fine=3, tooth=1.6, seed=142) * above
    p.wash(m, 0.84, rim=0.25, rim_w=4, gran=0.080, flow=0.22, seed=143)
    p.wash(m * smoothstep(0.42, 0.58, YN), 0.45, rim=0, gran=0.056, flow=0.3, seed=144)

    land = p.T / np.maximum(land0, 1e-6)
    water(p, yw, land, near=0.26, far=0.04, seed=151, squash=0.8)
    # light kept on the open water
    p.lift(0.55 * np.exp(-((YN - 0.69) / 0.035) ** 2) * smoothstep(0.52, 0.30, XN))
    ripples(p,
        lights=[(.20, .650, .12, .0050, .55), (.72, .655, .10, .0050, .55), (.46, .700, .09, .0060, .50),
                (.84, .720, .09, .0070, .55), (.30, .760, .13, .0080, .50), (.66, .800, .13, .0090, .55),
                (.90, .860, .08, .0100, .50)],
        darks=[(.24, .720, .09, .0060, .22), (.50, .790, .10, .0075, .25), (.16, .830, .11, .0085, .28),
               (.40, .900, .15, .0105, .30), (.72, .940, .12, .0110, .30)])
    return p.finish()


def variant_c() -> np.ndarray:
    """Island. A low horizon, a long pale range, one wooded island and a smaller one behind it."""
    p = Painting(paper_seed=9)
    yw = 0.655
    above = smoothstep(yw + 0.004, yw - 0.004, YN)
    sky(p, above, top=0.33, reach=0.52, seed=211)
    land0 = p.T.copy()

    far = p.profile([(-0.05, .540), (.12, .515), (.27, .465), (.36, .440), (.47, .485), (.60, .520),
                     (.74, .490), (.86, .455), (.95, .470), (1.05, .50)], wobble=0.005, wobble_sigma=26, seed=221)
    m = p.ragged(p.below(far), edge=2.5, rough=4, fine=2, seed=222) * above
    p.wash(m, 0.26 - 0.16 * smoothstep(0.44, yw, YN), rim=0.22, rim_w=5, gran=0.064, flow=0.16, seed=223)
    p.mist(yw - 0.03, 0.05, 0.62, seed=224)

    isl2 = p.profile([(-0.05, yw + .30), (.600, yw + .12), (.615, yw - .006), (.65, .622), (.70, .612),
                      (.74, .626), (.765, yw - .006), (.780, yw + .12), (1.05, yw + .30)],
                     wobble=0.002, wobble_sigma=10, seed=231)
    isl2 = treeline(isl2, [(.652, .030, 0.0033), (.676, .050, 0.0045), (.688, .028, 0.0031), (.728, .040, 0.0039)],
                    canopy=0.007, seed=3)
    m = p.ragged(p.below(isl2), edge=1.5, rough=3, fine=2.5, seed=232) * above
    p.wash(m, 0.48, rim=0.28, rim_w=4, gran=0.072, flow=0.2, seed=233)

    isl = p.profile([(-0.05, yw + .30), (.125, yw + .14), (.150, yw - .006), (.20, .598), (.28, .560), (.37, .575),
                     (.44, .612), (.485, yw - .006), (.505, yw + .14), (1.05, yw + .30)],
                    wobble=0.003, wobble_sigma=10, seed=241)
    isl = treeline(isl, [(.196, .060, .0058), (.226, .092, .0080), (.243, .066, .0060), (.292, .108, .0092),
                         (.311, .082, .0070), (.340, .058, .0056), (.363, .098, .0082), (.379, .060, .0056),
                         (.425, .062, .0056)], canopy=0.016, seed=4)
    m = p.ragged(p.below(isl), edge=1.3, rough=3, fine=3, tooth=1.6, seed=242) * above
    p.wash(m, 0.84, rim=0.25, rim_w=4, gran=0.080, flow=0.22, seed=243)
    p.wash(m * smoothstep(0.52, 0.64, YN), 0.45, rim=0, gran=0.056, flow=0.3, seed=244)

    land = p.T / np.maximum(land0, 1e-6)
    water(p, yw, land, near=0.28, far=0.05, seed=251, squash=0.72)
    ripples(p,
        lights=[(.31, .700, .13, .0050, .60), (.70, .705, .09, .0050, .55), (.52, .745, .10, .0065, .50),
                (.20, .790, .11, .0080, .55), (.80, .800, .12, .0080, .50), (.45, .870, .16, .0100, .50)],
        darks=[(.60, .770, .09, .0065, .24), (.86, .880, .11, .0095, .28), (.25, .900, .14, .0105, .30),
               (.62, .950, .13, .0110, .30)])
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    which = sys.argv[2:] or list(VARIANTS)
    for k in which:
        save_value(VARIANTS[k](), f"{out}/lake-{k}-value.png")
        print("painted", k)
