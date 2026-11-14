"""Checks the design tokens in docs/tokens.json against the brief.

- text contrast floor against the worst pixel of each style's paper, both appearances
- every swatch and palette accent at least 3:1 against both papers of every style
- no style token, swatch or palette colour is red

Run: python3 tools/tokens/check_tokens.py
"""
import colorsys, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
T = json.loads((ROOT / "docs" / "tokens.json").read_text())

FLOOR = {"paper": {"body": 17.7, "secondary": 6.8, "tertiary": 4.8},
         "ink": {"body": 16.2, "secondary": 8.3, "tertiary": 5.1}}


def rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(c): return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
def over(fg, bg, a): return tuple(f * a + b * (1 - a) for f, b in zip(fg, bg))


def contrast(a, b):
    la, lb = lum(a), lum(b); hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def is_red(c):
    """True red: hue within 15 degrees of 0 with real saturation. Browns and corals past 15 degrees pass."""
    h, s, v = colorsys.rgb_to_hsv(*c)
    deg = h * 360
    return (deg < 15 or deg >= 345) and s > 0.40 and v > 0.25


def worst_paper(style, app):
    """The paper pixel that gives text the least contrast: the base with the grain at full strength."""
    p = T["styles"][style][app]
    base = rgb(p["paper"])
    g = p.get("grain")
    return over(rgb(g["color"]), base, g["maxAlpha"]) if g else base


fails = []
rows = []
for style, sv in T["styles"].items():
    for app in ("paper", "ink"):
        p = sv[app]; ink = rgb(p["text"]); worst = worst_paper(style, app); base = rgb(p["paper"])
        # the grain must push toward the text colour, or the base would be the worst pixel
        if contrast(ink, base) < contrast(ink, worst):
            worst = base
        got = {"body": contrast(ink, worst),
               "secondary": contrast(over(ink, worst, p["secondaryAlpha"]), worst),
               "tertiary": contrast(over(ink, worst, p["tertiaryAlpha"]), worst)}
        for k, need in FLOOR[app].items():
            ok = round(got[k], 1) >= need
            rows.append((style, app, k, got[k], need, ok))
            if not ok: fails.append(f"contrast {style}/{app}/{k}: {got[k]:.2f} < {need}")
        for name in ("paper", "text"):
            if is_red(rgb(p[name])): fails.append(f"red token {style}/{app}/{name}")

papers = [(s, a, worst_paper(s, a)) for s in T["styles"] for a in ("paper", "ink")]
marks = {f"swatch {k}": v for k, v in T["swatches"].items()}
marks.update({f"accent {k}": v["accent"] for k, v in T["palettes"].items()})
mark_rows = []
for name, hx in marks.items():
    c = rgb(hx)
    lo = min(contrast(c, w) for _, _, w in papers)
    mark_rows.append((name, hx, lo))
    if lo < 3.0: fails.append(f"{name} {hx}: {lo:.2f} < 3:1")
    if is_red(c): fails.append(f"red: {name} {hx}")
for pname, pv in T["palettes"].items():
    for ramp in ("top", "bottom"):
        for hx in pv[ramp]:
            if is_red(rgb(hx)): fails.append(f"red: palette {pname} {ramp} {hx}")

if "--table" in sys.argv:
    print("| Style | Appearance | Text | Ratio | Floor |\n|---|---|---|---|---|")
    for s, a, k, g, n, ok in rows: print(f"| {s} | {a} | {k} | {g:.1f}:1 | {n}:1 |")
    print("\n| Mark colour | Hex | Lowest ratio on any paper |\n|---|---|---|")
    for n, h, lo in mark_rows: print(f"| {n} | `{h}` | {lo:.1f}:1 |")
for f in fails: print("FAIL", f)
print("ok" if not fails else f"{len(fails)} failures")
sys.exit(1 if fails else 0)
