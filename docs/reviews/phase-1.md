# Phase 1 reviews

Run on the plan and mockups at commit bb8a2da. Four of eight lenses have reported. Typography, senior engineer, performance and security stopped on a usage limit and have not reported.

Nothing below is fixed yet.

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
