"""Builds the phase 1 mockup assets and renders docs/mockups.html to PNG.

Run from the repo root:
    python3 tools/mockups/build.py assets   # scene tints, grain tiles, deckle mask, token injection
    python3 tools/mockups/build.py render   # PNG per frame and contact sheets

Offline tool. Needs numpy, scipy, Pillow and playwright with a Chrome install.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "scenes"))
import tint as T  # noqa: E402

DOCS = ROOT / "docs"
OUT = DOCS / "mockups"
TOKENS = json.loads((DOCS / "tokens.json").read_text())


def scene_tints() -> None:
    d = OUT / "scenes"; d.mkdir(parents=True, exist_ok=True)
    value = T.load_value(str(DOCS / "scenes" / "lake" / "lake-a-value.png"))
    v2 = np.asarray(Image.fromarray((value * 255).astype(np.uint8)).resize((700, 236), Image.LANCZOS)).astype(float) / 255
    for pal in T.PALETTES:
        for app in ("paper", "ink"):
            T.to_image(T.tint(v2, pal, app)).save(d / f"lake-{pal}-{app}.jpg", quality=90)


def tile(seed: int, sigmas, weights, size: int = 512) -> np.ndarray:
    """Seamless noise tile in 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for s, w in zip(sigmas, weights):
        n = ndi.gaussian_filter(rng.standard_normal((size, size)), s, mode="wrap")
        out += w * n / n.std()
    out = (out - out.min()) / (out.max() - out.min())
    return out


def grain_tiles() -> None:
    """Paper grain. Alpha never exceeds the maxAlpha in tokens.json, which is what the contrast check assumes."""
    d = OUT / "grain"; d.mkdir(parents=True, exist_ok=True)
    recipes = {"pencil": ((1.3, 3.2, 10.0), (0.45, 0.6, 0.55), 1.25),      # fine tooth
               "watercolor": ((1.4, 3.2, 9.0), (0.35, 0.6, 0.35), 2.2)}  # cold-press dimples
    for style, (sig, wts, power) in recipes.items():
        n = tile(11 if style == "pencil" else 23, sig, wts) ** power
        for app in ("paper", "ink"):
            g = TOKENS["styles"][style][app]["grain"]
            rgb = [int(g["color"][i:i + 2], 16) for i in (1, 3, 5)]
            a = np.clip(n * g["maxAlpha"] * 255, 0, g["maxAlpha"] * 255).astype(np.uint8)
            img = np.zeros((512, 512, 4), np.uint8)
            img[..., 0], img[..., 1], img[..., 2], img[..., 3] = rgb[0], rgb[1], rgb[2], a
            Image.fromarray(img, "RGBA").save(d / f"{style}-{app}.png", optimize=True)


def deckle_mask() -> None:
    """Ragged edge for the Watercolor scene card: the painting stops short of the frame on bare paper."""
    w, h = 700, 236
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    inset = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) - 7.0
    rng = np.random.default_rng(5)
    n = ndi.gaussian_filter(rng.standard_normal((h, w)), 6.0); n /= n.std()
    f = ndi.gaussian_filter(rng.standard_normal((h, w)), 1.6); f /= f.std()
    field = inset + 3.2 * n + 1.2 * f
    a = np.clip(field / 2.2, 0, 1)
    img = np.zeros((h, w, 4), np.uint8); img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(OUT / "scenes" / "deckle-mask.png", optimize=True)


def inject_tokens() -> None:
    p = DOCS / "mockups.html"
    s = p.read_text()
    block = "/*TOKENS*/" + json.dumps(TOKENS, separators=(",", ":")) + "/*END*/"
    s2 = re.sub(r"/\*TOKENS\*/.*?/\*END\*/", lambda m: block, s, flags=re.S)
    import base64
    uri = "data:image/png;base64," + base64.b64encode((OUT / "scenes" / "deckle-mask.png").read_bytes()).decode()
    s2 = re.sub(r"/\*MASK\*/.*?/\*ENDMASK\*/", lambda m: '/*MASK*/"' + uri + '"/*ENDMASK*/', s2, flags=re.S)
    p.write_text(s2)


def render() -> None:
    from playwright.sync_api import sync_playwright
    png = OUT / "png"; png.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        b = pw.chromium.launch(executable_path="/usr/bin/google-chrome", args=["--no-sandbox", "--force-color-profile=srgb"])
        page = b.new_page(viewport={"width": 1800, "height": 1200}, device_scale_factor=2)
        # the build is offline: any request that is not a local file fails it
        blocked = []
        page.route("**/*", lambda r: r.continue_() if r.request.url.startswith(("file:", "data:")) else (blocked.append(r.request.url), r.abort()))
        page.goto((DOCS / "mockups.html").as_uri())
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(600)
        ids = page.eval_on_selector_all("[data-shot]", "els => els.map(e => e.dataset.shot)")
        for i in ids:
            page.locator(f'[data-shot="{i}"]').screenshot(path=str(png / f"{i}.png"))
        b.close()
    if blocked:
        raise SystemExit(f"mockups.html tried the network: {blocked}")
    for i in ids:  # 256-colour palette keeps the repo small and is enough for a mockup
        f = png / f"{i}.png"
        Image.open(f).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(f, optimize=True)
    print(f"rendered {len(ids)} frames")
    sheets(png, ids)
    flow_sheet(png)
    m1_sheet(png, [i for i in ids if i.startswith("m1-")])
    m1_sheet(png, [i for i in ids if i.startswith("m2-")], "sheet-m2.png", 7)


def sheets(png: pathlib.Path, ids) -> None:
    """One contact sheet per style: rows are appearances, columns are screens. Half size."""
    screens = ["today", "detail", "gentle", "appearance", "marks"]
    for style in ("penAndInk", "pencil", "watercolor"):
        rows = []
        for app in ("paper", "ink"):
            ims = [Image.open(png / f"{style}-{app}-{s}.png").convert("RGB") for s in screens]
            ims = [i.resize((i.width // 2, i.height // 2), Image.LANCZOS) for i in ims]
            h = max(i.height for i in ims); w = sum(i.width for i in ims) + 24 * (len(ims) + 1)
            r = Image.new("RGB", (w, h + 48), (233, 230, 223)); x = 24
            for i in ims:
                r.paste(i, (x, 24)); x += i.width + 24
            rows.append(r)
        s = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows)), (233, 230, 223)); y = 0
        for r in rows:
            s.paste(r, (0, y)); y += r.height
        s.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(png / f"sheet-{style}.png", optimize=True)


def m1_sheet(png: pathlib.Path, ids, name: str = "sheet-m1.png", per_row: int = 8) -> None:
    """The milestone 1 screens in two rows, half size."""
    ims = [Image.open(png / f"{i}.png").convert("RGB") for i in ids]
    ims = [i.resize((i.width // 2, i.height // 2), Image.LANCZOS) for i in ims]
    rows = [ims[i:i + per_row] for i in range(0, len(ims), per_row)]
    w = max(sum(i.width for i in r) + 24 * (len(r) + 1) for r in rows); hs = [max(i.height for i in r) + 48 for r in rows]
    s = Image.new("RGB", (w, sum(hs)), (233, 230, 223)); y = 0
    for r, h in zip(rows, hs):
        x = 24
        for i in r:
            s.paste(i, (x, y + 24)); x += i.width + 24
        y += h
    s.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(png / name, optimize=True)


def flow_sheet(png: pathlib.Path) -> None:
    """The layouts and flows in one row, half size."""
    ims = [Image.open(png / f"flow-{k}.png").convert("RGB") for k in ("empty", "add", "count", "ax5", "watch", "mac")]
    ims = [i.resize((i.width // 2, i.height // 2), Image.LANCZOS) for i in ims]
    w = sum(i.width for i in ims) + 24 * (len(ims) + 1); h = max(i.height for i in ims) + 48
    s = Image.new("RGB", (w, h), (233, 230, 223)); x = 24
    for i in ims:
        s.paste(i, (x, 24)); x += i.width + 24
    s.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(png / "sheet-flows.png", optimize=True)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("assets", "all"):
        scene_tints(); grain_tiles(); deckle_mask(); inject_tokens(); print("assets built")
    if cmd in ("render", "all"):
        render()
