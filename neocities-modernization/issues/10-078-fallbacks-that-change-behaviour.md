# Issue 10-078: Fallbacks That Change What A Program Does

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open -- each fallback below waits on the owner's decision
- **Created**: 2026-11-03
- **Related**: 10-076 (removes the folder fallbacks: the assets folder and
  the two project-folder guesses), 10-071 (settings fallbacks; its checker,
  `scripts/audit-config-fallbacks`, finds 0 today), 10-065 (values given
  explicitly)

## Current Behavior

Owner, 2026-11-03: "should remove fallback defaults". The settings checker
(`scripts/audit-config-fallbacks`) only sees the shape "a setting `or` a
value", and finds none. A search for the word "fallback" in `src/` and
`libs/` finds code paths of another shape: when the first way of doing
something fails, the program quietly does it a second way. Each one:

1. **Terminal width** (`libs/progress-display.lua`, `FALLBACK_COLS = 80`):
   when neither the terminal nor `COLUMNS` gives a width, progress bars are
   drawn 80 columns wide.
2. **Diversity walk with no similarity data**
   (`src/diversity-chaining.lua`): when a poem has no similarity entries,
   the next poem is "any unused poem" -- the first one the table walk
   meets -- with a warning in the log, and the walk goes on.
3. **Picture size unknown** (`src/image-manager.lua`, the dimension
   reader): when ImageMagick's `identify` gives nothing, the picture is
   catalogued with no width and height, and nothing is said.
4. **Menu without the TUI library** (`src/main.lua`, the interactive
   menu): when the TUI library cannot be loaded, a plain text menu is shown
   instead.
5. **A poem's date** (`src/poem-dates.lua`): the creation-date field
   (full timestamp, then date only); then a date written at the top of the
   poem's text (three spellings); then the file's creation time. Only after
   all of those is a poem without a date an error (Issue 8-045).
6. **An extracted post's date** (`src/poem-extractor.lua`): a full
   timestamp, then a date-only one.

7. **The embedding-server manager runs when loaded**
   (`src/embedding-server-manager.lua`, found 2026-11-03 while Issue 10-076
   changed how it reads its folder): its last lines start its own main
   whenever the global `arg` exists, and `src/main.lua` loads it -- so a
   program loading it runs it. Not a fallback, but the same shape of
   surprise: the module does a second thing nobody asked for.

Items 5 and 6 are partly formats rather than fallbacks: one field written
two ways is one source read carefully. The text-of-the-poem and
file-creation-time steps in item 5 are fallbacks: a different source,
used silently, so two poems can get their dates by different rules with
nothing saying which.

## Intended Behavior

Decided one by one with the owner (see Open questions). For each, either:
- the second way is removed and the first way's failure is an error that
  says what was missing; or
- it stays, marked in the code with a comment containing "optional:" and
  the reason, the way `scripts/audit-config-fallbacks` already accepts
  declared optional settings -- and, per the owner's rule, it says so on
  the terminal every time it is used.

## Suggested Implementation Steps

1. Ask the questions below, one at a time; write each answer here.
2. For each fallback to remove: make the failure an error naming what was
   missing; add a test that the error happens.
3. For each to keep: the "optional:" comment and a notice when it is used.
4. Teach `scripts/audit-config-fallbacks` (or a sibling checker) to find
   this shape too -- a commented "Fallback" branch -- so the list can be
   re-run rather than trusted.

## Open questions

1. Terminal width: when the width cannot be read, stop, or draw at 80?
2. Diversity walk: a poem with no similarity data -- stop the walk with an
   error naming the poem, or keep picking "any unused poem"?
3. Picture size: a picture `identify` cannot read -- stop the catalogue
   naming the picture, or catalogue it without a size?
4. Menu: no TUI library -- stop and say where it was looked for, or show
   the plain menu?
5. Poem dates: keep reading the date from the poem's text and from the
   file's creation time, or take dates only from the creation-date field
   and stop on a poem that has none?
6. Post dates: a timestamp with no time part -- accept it as midnight, or
   stop?
7. The server manager: run its main only when it is the program started
   (the test the other dual-use modules use), or is running when loaded
   wanted?
