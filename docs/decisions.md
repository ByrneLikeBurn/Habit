# Decisions

One entry per decision that changed the brief. Each says what changed and why, in two or three sentences. Newest last. Details are in `docs/spec.md`.

## 14 November 2026

**Year view uses shapes, not opacity.** The brief asked for four opacity steps. Three reviews measured neighbouring steps at 1.2:1 to 1.5:1, so an empty day and a part-done day looked the same. Each state is now a small shape.

**A day with no log draws nothing.** The brief drew a missed day as an empty outline. That is a mention of a missed day, which invariant 1 forbids unless the user opts in. One switch, "Show days not logged", brings the outline back.

**Whole-number amounts, typed.** The brief stored each log as plus or minus one. A habit of 15,000 steps would need thousands of events. A log now stores any whole number, and every number in the app can be typed.

**An entitlements file is allowed for the App Group.** The brief banned the file to keep CloudKit out. Widgets and the Watch need a shared store, which needs the file. CloudKit is still out.

**Milestones reordered.** Milestone 1 is the core loop in Pen and ink, with Edit, Archive and manual order. Export and import moved to milestone 2, because the phone holds the only copy of the data. Pencil and Watercolor are milestone 4.

**Scene art is supplemental.** Scenes moved to milestone 5. The art does not change whether the app works, and it was the slowest part of the design. Marks default to Blue until then.

**Red is allowed as a user's accent.** The brief said no red anywhere. Some cultures read red as lucky, and a colour the user picks carries no meaning from the app. The app's own colours still never use red.

**Three reviews per milestone, twenty at the stops.** Eight at once hit the usage limit twice. Engineer, QA and tired daily user run after each milestone, with accessibility and security added when relevant.

**Twelve lenses added.** Product owner, first-day user, content designer, QA, release engineer, UI and UX, human factors, senior designer, behavioural scientist, neurodiversity expert, returning user and illustrator. The first eight covered engineering and visual design but not behaviour, inclusion, flows or release.

**Three tabs.** Tags moved into You. NFC is a shortcut, works on iPhone only, and arrives late, so it did not earn a quarter of the navigation.

**A control-side setting.** A left thumb cannot reach a control on the trailing edge of a large phone. One setting in You moves the control to the leading side.

**Reviews may override the brief on design.** The brief began as an idea, and development follows evidence. Privacy, dependencies, the schema rule and cost stay with the owner, and so does any case where two reviews disagree.

**A counted habit may have no target.** Three reviews said a required target turns a count into a pass or fail test. With no target, any log draws as done. Something is better than nothing.

**A part-done day never breaks a run.** A day at 7 of 8 was scored the same as a day with nothing. Habit detail now shows "Days logged" beside "Days done".

**One widget in milestone 3.** Milestones 1 to 3 gave the user no cue outside the app. A Home Screen widget is a cue the user places, and it carries no guilt.

**"Extra credit" became "Logged while paused".** Three reviews read the old name as grading language. The rule itself did not change.

**Data rules accepted.** Ten rules for how logs are stored, from the engineering and QA reviews. They are fixed before milestone 1 because stored data can only be added to later.

## 15 November 2026, milestone 1

**The shared store works with free signing.** A throwaway project with an app and a widget shared one App Group on the owner's iPhone. The widget read what the app wrote in shared settings, a file and a SwiftData store. Milestone 1 builds on that store.

**Day keys use the Gregorian calendar.** A key is yyyymmdd, and a non-Gregorian calendar would make stored keys mean different days for different users. Keys are Gregorian in the user's time zone, and dates are shown in the user's own calendar.

**Two tabs until history exists.** Progress has nothing to show before the heat map in milestone 2. An empty tab is a dead end, so Today and You are the only tabs until then.

**An off-schedule log reads "Logged on a day off".** The data rules credit a log on an off-schedule day like a log on a paused day, and both draw the diamond. "Logged while paused" would be untrue on a day that was never paused, so VoiceOver and the marks board use their own words for it.

**A part-done day extends a run.** The spec says a part-done day never breaks a run. Something is better than nothing, so it also counts toward the run, as any logged day does. A tested rule keeps it from drifting later.

**The models hold what milestone 1 uses.** `Habit` has the fields milestone 1 needs, and `Pause` exists now so the set of models does not change in milestone 3. Focus, nudge, tag and descriptor fields are added in the milestone that first uses them, which the additive schema rule allows without a new schema version.

**An empty tap amount opens the count sheet.** `tapAmount` is optional with a default of 1, and empty means a tap opens the sheet. That is what the spec asks for above a target of 20, and it needs no special number.

**A yes-or-no tap always lifts the day to done.** Two devices taking back one log offline can leave a total of −1, which shows as 0. A tap then writes enough to reach 1, so it is never swallowed. Typed amounts are always written as typed.

**Archived habits still log from Shortcuts.** A tag or shortcut that stopped working would break invariant 4. The intent logs it and says the habit is archived and can be brought back in You.

**The Undo line waits for VoiceOver.** It shows for five seconds. With VoiceOver on it stays until the next action, because five seconds is too short to reach the button. System undo also takes back the last log.

**The count sheet amount starts selected.** The UI test found that typing 12 after the tap amount of 1 gave 112. The amount now starts focused and selected, so typing replaces it and Add still works with no typing.

**Mark colour sits on the Appearance page.** The milestone 1 mockup shows the eight swatches on the page itself. The separate "Marks" list in the spec comes with "Follow the scene" in milestone 5.

**Large text gets lists where controls do not grow.** A segmented control keeps its small text at accessibility sizes. At those sizes Kind and Light or dark become lists, and symbol cells grow with the text.

**Each reason sits under its field.** If Add is disabled, the reason appears under the field that causes it: the name, the target, the tap amount or the days. A reason at the bottom of the form would be off screen while the keyboard is up.

**Cancel asks before throwing away changes.** A swipe down is blocked when the form has changes, and Cancel asks "Discard changes?". Without changes Cancel closes at once.

**The signing team is not committed.** The team id lives in `Config/Local.xcconfig`, which git ignores, with an example file beside it. The repo is public and the id is tied to a person.

**Screenshots are half-size JPEGs.** Thirty-seven PNGs at full size would add about 20 MB to a public repo. `tools/screenshots/m1.sh` makes them the same way each time.
