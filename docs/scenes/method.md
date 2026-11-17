# Scene method: open question

Raised by the owner on 16 November 2026: "These don't look like water colors. It looks like a monochromatic drawing, not a watercolor. Watercolor behaves differently than what is rendered here. Even the previously approved images look more like drawings than watercolors."

The owner also said that "old conifer forest" is an acceptable reading for Redwoods, because the scenes are for tone and ambiance and not for detail, and that they are unsure the work on Redwoods serves the app.

## Cause

`CLAUDE.md` locks scene art as one greyscale value layer per scene, tinted at runtime by the palette. One layer and one ramp of colour give one hue per place in the card. Real watercolour has several pigments, soft edges where paint met wet paper, and pigments that bleed into each other. The even grain in every wash reads as print.

## Experiment

`tools/scenes/wet.py`, picture `docs/scenes/redwoods/redwoods-two-pigment.jpg`. Row 1 is the current method. Rows 2 to 4 try three things on the same painting, in Midday, Sunrise and Night:
1. Two pigments. A second layer says where the earth pigment goes (trunks and floor) and where the leaf pigment goes (ferns and the light behind).
2. Wet into wet. Far shapes lose their edges, and the two pigments bleed where they meet.
3. Less stipple.

The earth ramps in the experiment are not in `docs/tokens.json`. They are brown, not red.

## What a change would touch

- The locked decision "Scene art": a second layer per scene. It can be stored at a quarter of the size, so it adds little to the 300 KB per scene.
- Every palette needs a second ramp. Invariant 6 holds: both ramps still follow the clock only. Invariant 7 holds if no ramp is a true red.
- The approved Lake, Massif and Tarn would be repainted with a second layer and shown to the owner again.
- A computed painting has a ceiling. The other route to real watercolour is paintings made by hand and scanned. That brings cost and a licence, which are the owner's.

## Status

Not decided. This is a rule later work builds on and it changes a locked decision, so it goes to the illustrator, senior designer, colour vision and performance lenses, and then to the owner. No further scene is painted until it is settled. Scenes are milestone 5 and do not hold up milestones 1 to 3.
