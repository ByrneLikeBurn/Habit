# Asset licenses

Every font and texture in the repo, with source and hash.

## Fonts

These are in `docs/mockups/fonts/` for the phase 1 mockups only. No font ships in the app until the owner picks one. The files are unmodified. Each folder holds the font's `OFL.txt`.

The files were downloaded from the Google Fonts repository, `github.com/google/fonts`, which mirrors each upstream repository at the commit listed.

| File | License | Upstream | Upstream commit | Downloaded from | SHA-256 |
|---|---|---|---|---|---|
| `alegreyasans/AlegreyaSans-Regular.ttf` | SIL OFL 1.1 | github.com/huertatipografica/Alegreya-Sans | 030b9ac01fd9bcaccac0ebc8010283175f9ced4e | github.com/google/fonts/tree/main/ofl/alegreyasans | 8fab634196007afca839f1e5a6fb300976daff55d8528b590ef032f01b14ea10 |
| `alegreyasans/AlegreyaSans-Medium.ttf` | SIL OFL 1.1 | same | same | same | 4b89fe7804fd1485ec2757795a53ffdb66e1206dd56f844c2d72b3c944815b43 |
| `alegreyasans/AlegreyaSans-Bold.ttf` | SIL OFL 1.1 | same | same | same | a3055a1893759bdbd7504bb22abc583769e7974c49353176eac0b03792c9fb8e |
| `fraunces/Fraunces[SOFT,WONK,opsz,wght].ttf` | SIL OFL 1.1 | github.com/undercasetype/Fraunces | d6d385783609ceb11ac0f220f3abd9f1631c8a36 | github.com/google/fonts/tree/main/ofl/fraunces | 177ff6c0f14e5550a3c624247cd1189611d4eb65d000b14944c63d967958abbb |
| `shantellsans/ShantellSans[BNCE,INFM,SPAC,wght].ttf` | SIL OFL 1.1 | github.com/arrowtype/shantell-sans | 68f5eca1490a58973b2a814d3a7d0f61291fd0c9 | github.com/google/fonts/tree/main/ofl/shantellsans | d98a7913853f78d71aa0b86daf66b5eddb5a3266c07bfd51ef70632b88c41084 |
| `playpensans/PlaypenSans[wght].ttf` | SIL OFL 1.1 | github.com/TypeTogether/Playpen-Sans | e9de3f5df6328821ed98775d347b8da652fc47fc | github.com/google/fonts/tree/main/ofl/playpensans | e083f9da8be210e08ea982ab510894641aab37590e70620d6db73f8de881ec4a |

Fonts named but not in the repo: New York, SF, Optima and Chalkboard SE are installed with the OS. Charter and Inter appear only in PNGs rendered on Linux, as stand-ins for New York and SF, and are not in the repo.

## Textures and scene art

All of these are drawn by code in this repo. None comes from a stock source.

| File | Made by |
|---|---|
| `docs/scenes/lake/lake-*-value.png` | `tools/scenes/lake.py` |
| `docs/scenes/lake/*.jpg` | `tools/scenes/sheets.py` |
| `docs/mockups/scenes/*` | `tools/mockups/build.py` |
| `docs/mockups/grain/*.png` | `tools/mockups/build.py` |
| `docs/tint-luts.json` | `tools/scenes/export_luts.py` |

## Tools

The Python tools need numpy, scipy, Pillow and playwright, at the versions in `tools/requirements.txt`. They run offline on a developer machine. The app does not depend on them.

Before any font ships in the app it is downloaded again from its upstream repository, and that hash is recorded here.
