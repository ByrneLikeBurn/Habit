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

## Owner, later on 16 November 2026

"The two pigments is confusing. The issue is not the pigments but the lack of the distinguishing features of a water color. What you created was a passable drawing, but not a water color. How close can we get to replicating those distinctive features?"

The two-pigment idea is dropped. The second layer and the second ramp are not needed.

## Second experiment: the marks of watercolour, one pigment

`tools/scenes/wc.py`, picture `docs/scenes/watercolour-marks.jpg`. A loose study of conifer trunks in the current one-layer format, so it needs no change to the locked decision. It tries eight marks: wet into wet, the dried edge, pooling, backruns, granulation, glazing, dry brush, and shapes made of a few loose strokes.

What the earlier scenes did that reads as drawing: every shape had the same crisp, toothed edge; every wash was filled evenly; an even fine stipple covered everything; shapes were built from many small exact strokes.

Known faults in this study: the fringe of each backrun is a thin even line and reads as drawn; the trunks wobble too much; the ferns read as agave. It has not had a blind test or a review.

## Owner on the study, 16 November 2026

"Way further off. Now they look like weird squiggles. The intent is somewhat there. But they no longer look like redwoods."

Cause: the study let every edge wander and drew a line round each backrun. A trunk has to stay straight to be a trunk.

## Third experiment: the drawing's form, the paint's behaviour

`redwoods_painted()` in `tools/scenes/wc.py`, picture `docs/scenes/redwoods/redwoods-painted.jpg`. The second Redwoods drawing supplies the form: straight tapered trunks on one ground plane, flared feet, ferns. The paint supplies only what depends on how wet the paper was: far trunks are soft, near trunks have a hard dried edge, washes pool and granulate, bark is a second glaze of long straight strokes. No trunk wanders and no backrun has a line.

Known faults: two dark blots among the ferns, and the ferns are faint at card size. Not blind tested or reviewed.

Stop rule agreed with myself and put to the owner: if this does not read as both redwoods and paint to the owner, computed scenes are parked until after user testing of milestones 1 to 3.
