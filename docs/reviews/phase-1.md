# Phase 1 reviews

Run on the plan and mockups at commit bb8a2da. All thirteen lenses have reported. The first four ran at commit bb8a2da. The other nine ran at commit 76f9069, after the first fixes.

Status after the fix commit: 1 and 2 were decided by the owner and are applied. 3 to 17 are fixed in the mockups or written into `docs/spec.md`, except as listed here.

- 6: layouts are mocked for the largest text size, Mac and Watch. iPad is not mocked. It uses the Mac layout.
- 15: the Pencil box is now four strokes that overshoot their corners. It was not re-reviewed.
- 17: Increase Contrast and Reduce Transparency are specified in `docs/spec.md`. They are not drawn.

## Conflicts inside the brief. The owner decides.

1. **Year view.** The brief asks for solid ink at four opacity steps. Invariant 2 says heat-map intensity is hatching density and state is never carried by intensity. Neighbouring steps measure 1.2:1 to 1.5:1 and the lowest step is 1.1:1 against paper. Paused, extra credit and off schedule have no form in the view. Raised by: Apple designer, colour vision, accessibility.
2. **Days not logged.** The mark vocabulary draws a past day with no log as an empty outline by default. Invariant 1 says no mention of a missed day unless the user opted in. On Habit detail, "Current run 2 days" above "Longest run 31 days" reads as a loss. Raised by: tired daily user.

## Valid. To fix in the mockups and spec.

3. An empty outline has three meanings (not logged, today with nothing logged, today off schedule) and they differ only by colour or a few points of size. With the graphite accent they match. Raised by: Apple designer, colour vision, accessibility, tired daily user.
4. In Gentle Mode the only control on a row is a small dash. It does not look tappable. Raised by: tired daily user, Apple designer, colour vision.
5. Watercolor marks are under 3:1 as drawn: 2.2:1 to 2.7:1, lower with the sunrise accent. `check_tokens.py` measures the flat colour, not the drawn opacity, so it passes. Raised by: accessibility, colour vision, Apple designer.
6. No layout exists for AX5, iPad, Mac or Watch. At AX5 the three-line clamp cuts the habit name to "Write three lines in the". The Appearance tiles and scene picker do not fit at large sizes. Scene picker cells are 41 pt tall. The scene card is a fixed 350 by 118 pt and has no rule for wide windows. The Tags tab has no use on iPad or Mac. Raised by: Apple designer, accessibility.
7. The extra-credit diamond covers about a fifth of the area of a done mark. Raised by: tired daily user.
8. "Every day" repeats under five rows. "Paused" repeats under five rows below a note that already says it. Raised by: tired daily user.
9. The month grid has no day numbers, and no date in the VoiceOver label. Leading blanks and off-schedule days look the same. The spec has no VoiceOver name for "today" or "nothing logged yet". Raised by: accessibility, tired daily user.
10. Habit detail shows a back button to Today with the Progress tab selected. Raised by: Apple designer.
11. The Appearance screen uses radio buttons, which iOS does not have. Accent swatches have no selected state. Raised by: Apple designer.
12. Screen headings are set in the display font. The spec does not say whether they are navigation titles, which would restyle system chrome, or content. Raised by: Apple designer.
13. The far ridge of the Lake is faint in Sunrise and Midday: 1.31:1 and 1.40:1 on Paper, 1.19:1 and 1.25:1 on Ink. Raised by: colour vision.
14. Sunset ramp stops sit 0.8 to 4.6 degrees from the red hue limit. Raised by: colour vision, Apple designer.
15. Pen and ink and Pencil marks look alike at 20 pt. Raised by: Apple designer.
16. The key label "Ahead" reads as a performance word. Raised by: tired daily user.
17. No Increase Contrast or Reduce Transparency variant of any mark is drawn or specified. Raised by: accessibility, Apple designer.

## Valid. Not fixed, with the reason.

- Under simulated tritanopia Sunset tests as red on 20% of pixels on Paper and 53% on Ink, and the Sunset accent tests as red. Any warm hue moves toward red in that simulation, Sunrise included. State is carried by shape. Raised by: colour vision.
- The "ahead" mark is under 2:1 in every style. The brief asks for reduced opacity so that a future day can never look missed. Raised by: accessibility, colour vision.
- "Extra credit" reads as grading language. It is the brief's term. Raised by: tired daily user.

## Second round: nine lenses at commit 76f9069

### Fixed

- Senior engineer: the contrast check rounded before comparing, so two Pen and ink Paper tokens under the floor passed. The check now compares unrounded and the tokens were raised.
- Senior engineer: the mark check used the grained paper in Ink, which flatters a mark. It now takes the lower of bare and grained paper.
- Senior engineer: the spec's contrast tables were pasted output. They are now `docs/contrast.md`, written by the checker. The floors moved into `docs/tokens.json`.
- Senior engineer: no test vectors existed for the Swift tint. `docs/tint-luts.json` holds them. Dead helpers in `tint.py` were deleted. Tool versions are pinned in `tools/requirements.txt`.
- Security: the mockup render ran Chrome with no network block. Any request that is not a local file now fails the build.
- First-day user: a counted habit had no visible way to subtract. The count line under the name now opens the count sheet.
- First-day user: Gentle Mode had no visible way out. The Today line has a "Turn off" button.
- First-day user: nothing said a past day can be tapped. One line under the month grid says so.
- First-day user: the New habit sheet used a dashed circle for an unselected day, which is the drawing for "to come". It is now a solid thin circle. The key gained "Today". The Watch shows the count.
- First-day user: "Appearance" was the name of both the page and one section. The section is now "Light or dark".
- Content designer: VoiceOver said "Nothing logged" for a day the screen keeps silent. Such a day is now read as the date alone.
- Content designer: the count sheet buttons were named "One less" and "One more" whatever the step. They are "Decrease" and "Increase" with the step. The hint line was removed and the number is a field.
- Content designer: the scene card label used the palette key "bluehour". It uses the display name.

### Written into the spec as rules for phase 2

- Senior engineer: the data rules, the injectable clock, and the tests to add.
- QA engineer: two-device taps, target and schedule changes against history, day-start and time-zone edges, part logs on paused days, pause edges, import twice, narrow widths.
- Performance: baked mark geometry, one Canvas for the year view, an alpha grain tile, one tinted scene in memory, 8-bit scene layers.
- Typographer: Bold Text weights, lining and tabular digits, slashed zero in Pencil counts, variable-font axes, no cut names at large sizes.
- Release engineer: fixed bundle and group ids, privacy manifests, when the notification prompt appears, widget tint modes, icon variants, the 7-day limit.
- Content designer: locale rules for week start, dates, lists and plurals.

### For the owner. See "Open decisions" in `docs/spec.md`.

- Product owner: milestone 1 is too large. Export is too late. Thirteen lenses per stop costs too much.
- Release engineer: the brief forbids the `.entitlements` file that a shared store needs.
- Senior engineer and QA engineer: the `delta` proposal and the data rules.

### Not fixed, with the reason

- Security: the mockup fonts came from the Google Fonts mirror, not each upstream repository. No font ships yet. The spec requires the upstream file before one does.
- Security: the Fraunces license file says 2018 and the font says 2020. Fraunces is not a pick.
- Typographer: Alegreya Sans ExtraBold is not in the repo. It is added when the font is picked.
- Product owner: merge the colour-vision lens into accessibility and the typographer into the Apple designer. Not done. In this round each of those lenses found things the other did not.
- Content designer: rename Gentle Mode and reword "Extra credit". Both are the brief's own terms. A translator note was added for "Extra credit".
- First-day user: no key on Today. A key on Today adds noise for the daily user. The key is on Habit detail and in You.
- Release engineer: whether a free Apple account can use App Groups could not be confirmed from Apple's pages. It is tested before milestone 1.
