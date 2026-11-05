# Phase 3 Progress — The relay through rmail

## Goals
kuvalu's mailbox on port 1223, the arrival hook, the canvas mailed to the
voices as a living message, and the turn hook that keeps only the newest
canvas and runs one turn at a time. Rehearsed on kuvalu with stand-in
mailboxes. Ends with the measured round trip through real rmail.
(`docs/roadmap.md`, phase 3)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
(Each completed issue adds a line here saying what it built and how it
moves the phase toward its goals.)

- **301, the guide mailbox** (2026-11-05): `scripts/make-mailboxes`
  (`src/031-mailboxes.lua`) makes every mailbox from one list,
  `input/mailboxes`: kuvalu's guide mailbox on port 1223 and the three
  voices. Each linked pair gets its own secret, in the two `contacts`
  files only, and both hooks point at the arrival or turn hook through a
  wrapper in the mailbox. A mailbox already there is adopted, never
  overwritten. Starting the daemon on kuvalu is the owner's.
