# Milestone 4: gates and owed items

`docs/findings.md` is the one list of findings. It is being edited on `feat/history`, so these wait here and are copied into it when this branch is merged. Each has a test and what happens if it fails.

## Gates before the milestone 4 build merges

| Gate | Lens | Test | If it fails |
|---|---|---|---|
| Watercolor control in black | Human factors | One row shown for a glance under Increase Contrast. Does the disc in a ring read as a radio button, the paused dab as a delete button, the diamond as stepper arrows | The mark changes before it is built. The owner's view, recorded in `docs/spec-m4.md`: the ring's varied line weight keeps it from reading as a radio button |
| Watercolor paused dab and diamond in colour | Human factors | The same glance test without Increase Contrast | The mark changes before it is built |
| Plus in the Pen and ink counted control | Human factors, first-day user | Whether Pen and ink drops its plus, as Pencil and Watercolor have none | Pen and ink keeps its plus |
| Names at the largest text size | Accessibility | A three-line name and a 58-character name in each style at the largest size, with Bold Text | The row gap grows with the text size in Watercolor |
| Slashed zero at the largest size | Neurodiversity | Pencil's zero at the largest text size | The `zero` feature is turned off above a set size |

| Appearance page on the Mac | Apple industrial designer | A 700 point window leaves the right half empty with the column capped at 360 | The column is centred or the tiles sit in a row |

Closed on 16 November 2026 by a drawing and a measurement: Pencil part done at 24 points, the style picker at the largest text size, the 360 point cap.

## Owed: a fix is applied and no lens has measured it since

| Item | Rule | Last measured | Fix applied |
|---|---|---|---|
| Bare paper between "to come" dashes under Increase Contrast | 2 points | 1.7 | 1.9 points of extra spacing |
| Watercolor done mark clear of its ring under Increase Contrast, on Paper | 3 points | 2.69 | A less uneven disc edge, the ring 0.9 of a point larger |
| Pencil row line under Increase Contrast | 3:1 | 1.87 and 2.30 | Drawn flat at half strength across the full point |
| Pencil marks under Increase Contrast, smoothed edges | Marks told apart after the blur | Not measured | Smoothed after the owner's feedback |

## Still to do in milestone 4 design

- Step 5: the Bold Text weight pair for each style, upstream file hashes for `docs/asset-licenses.md`, ExtraBold for Alegreya Sans.
- Step 7: the colour ring, as the last and separate PR.

## From Claude Code's branch, read on 16 November 2026 at `6623c48`

`feat/history` now defines a habit with no set days (`DayState.noSetDays`): the small dot on today until logged, read as "No set days". These touch milestone 4 design and are not drawn yet.

| Item | Source | What the design branch owes |
|---|---|---|
| The no-set-days dot inside the Today control | `docs/decisions.md` on `feat/history`, "Its marks" | Draw it in the Pencil square and the Watercolor ring, with the 3 point clearance, and under Increase Contrast |
| Plus alone against plus with dot | Gate for milestone 4 in `docs/findings.md` on `feat/history` | Pencil and Watercolor have no plus, so the gate applies to Pen and ink only. It bears on the open question of whether Pen and ink drops its plus |
| Two split diamonds side by side read as an up-down chevron | Gate for milestone 4 | Check the Pencil tilted gap and the Watercolor curved diamond in a History month row |
| History month strip and Habit detail year grid at the largest text size, in all three styles | Gate for milestone 4 | Draw both in Pencil and Watercolor |

Invariant 3 in `CLAUDE.md` was reworded on `feat/history`: "Under no set days a pause changes nothing." The design branch still has the older wording. It comes in when `main` is merged after PR #12.
