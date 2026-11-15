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
