# Mountains: scene gate record

Not approved. No scene is built until the owner approves a variant. Painted by `tools/scenes/mountains.py`.

## Variants, 16 November 2026

| Variant | What it is | Reviews |
|---|---|---|
| A, Massif | One broad snow peak, valley mist, a dark wooded spur at left | Second. To fix before the owner sees it: snow on one side of each summit, broken by rock ribs at uneven spacing, with no outline. The spur's tree tips read as towers, which the Lake log already rejected |
| B, Ranges | Five ridges, pale to dark, mist lying along the valleys, one small snow cap | First choice of the illustrator, the senior designer and the product owner. The only variant with no water and no wooded point |
| C, Tarn | Two snow peaks mirrored in still water | Dropped. Both reviews said it is the Lake again with taller ridges |

Changed in B after review: the mist bands were straight and equal, and read as ruled stripes. They now tilt along the valleys and vary in depth. The far right summit is higher and has one small cap of bare paper, so the picture reads as mountains and not hills.

Open, for the illustrator and then the owner:
- B has no mirrored lower half. `docs/spec.md` says every scene is built on a fold. Does mist count as the fold?
- B stacks five ridge lines. Invariant 7 says one soft horizon.
- A third variant with no water is owed, to replace C.

Sizes: value layers are 164 to 168 KB at 3x, against 155 KB for the Lake. About 250 KB per scene with the 2x file. Five scenes fit in 1.5 MB. A sixth does not.

## The scene set. Reviewers' answers to the owner's question

Missing: every planned scene is dramatic wilderness. Flat, open, everyday land is absent.

| Candidate | Illustrator | Senior designer and product owner |
|---|---|---|
| Open grassland or meadow: low horizon, wide sky, one line of flat-crowned trees | Suggested | Park. The strongest candidate for people who do not live near mountains or sea |
| Reed marsh or delta: water channels between reed banks | Suggested | Park. Close to the Lake |
| Karst hills: rounded limestone peaks in stepped mist above a flat river | Suggested | Not asked |
| Snowfield or tundra | Not raised | No. Reads as weather, and is mostly bare paper |

Other art in the same card:
- Worth one drawing: graded washes with one soft horizon and no subject. Both reviews raised a version of this. It can also serve as a "no scene" option.
- Worth one drawing: still water seen close, ripples only.
- Needs the owner, because it breaks "one soft horizon": a botanical study. It must never grow or wilt.
- Not to do: still lifes, sun or moon discs, stars, seasonal art, patterns that could read as a chart, anything that grows with use.

None of this belongs before user testing of milestones 1 to 3. Scenes are milestone 5. A sixth scene needs a larger size budget, which is the owner's decision.

## Illustrator, round two, on B

Passed: the mist and the summit. Owed: the snow cap vanished at one-third size. It is now twice as wide. The illustrator has not seen that version.

Rulings:
- Horizon: not a breach of invariant 7. Sky meets land along one soft line, and the nearer ridges are land in front.
- Fold: mist does not count as the fold. B needs a written exception in `docs/spec.md`: the fold applies where a scene has water, and other scenes use receding layers. Redwoods and Desert would build on that rule, so it is a rule later work builds on. It goes to the scene lenses, and then to the owner with the variant.

B is ready for the owner, with the fold exception stated.
