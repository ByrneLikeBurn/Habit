# Phase 2 kickoff

Phase 2 needs Xcode, so it runs in Claude Code on the owner's Mac.

## Steps for the owner

1. Install Xcode 26 from the App Store and open it once.
2. In Terminal: `git clone https://github.com/ByrneLikeBurn/Habit.git` and `cd Habit`.
3. Start Claude Code in that folder.
4. Paste the prompt below.

## Prompt to paste

Read `CLAUDE.md`, `docs/spec.md` and `docs/decisions.md` in full before you start. They are the brief. Where they differ from anything older, they are right.

Do these in order. Stop where it says stop.

1. **Shared-store test.** In a folder outside this repo, make a throwaway Xcode project with an iOS app and a widget extension that share one App Group, signed with my personal team. Write a value in the app and read it in the widget on the simulator and, if I plug one in, on my iPhone. Tell me whether it works. Stop and wait for me.
2. **Milestone 1.** Build what `docs/spec.md` lists for milestone 1, on a branch named `feat/core-loop`. The screens are in `docs/mockups/png/sheet-m1.png`. It includes the row menu, the "Not scheduled today" row, the plus on a counted control, and the Undo line.
3. After milestone 1, run the three reviews named in `CLAUDE.md`, plus accessibility. Fix what is valid. Open the PR and stop. Do not merge.

Rules that matter most: the invariants in `CLAUDE.md`, the data rules in `docs/spec.md`, and "something is better than nothing". Report every decision you make in two or three sentences and add it to `docs/decisions.md`.

## What milestone 1 does not hold

No scene card, no palettes, no Pencil or Watercolor, no heat map, no pausing, no widget. Those are later milestones.
