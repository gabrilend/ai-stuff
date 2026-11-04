# check-poem-dates.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/check-poem-dates: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
check-poem-dates -- confirms every poem has a date the site can place.

WHAT IT DOES (for a CEO): every poem's progress bar shows how far through
the writing years it was written, and the chronological pages list poems in
date order.  A poem with no date cannot be placed, and the page build stops
on it -- hours into an overnight run.  This runs the same date reading and
ordering the page build uses, in seconds, before the build starts, and
lists the first undated poem.  It changes nothing.  (Issues 8-045, 10-069.)

Usage:  luajit scripts/check-poem-dates [--dir PATH] [--poems FILE]
  --dir PATH    project directory (default below)
  --poems FILE  the poem list to check (default DIR/assets/poems.json)
  A word with no flag in front of it stops the script (Issue 10-076).
Exit status: 0 when every poem has a date, 1 otherwise.

--help: print the header above and exit, before any work (libs/script-help.lua)
```
