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
- **302, the arrival hook** (2026-11-05): `scripts/arrival-hook`
  (`src/033-arrival-hook.lua`) takes a voice's canvas from the guide
  mailbox, on its first arrival and every edit after, and writes it into
  the blitter's arrivals folder, printing nothing and exiting at once.
  Anything that is not a canvas is logged and left alone. The real
  blitter makes new versions from what it writes.
- **303, the canvas sent to the voices** (2026-11-05): the blitter, run as
  a program, rewrites one living message, `outbox/the-canvas` in the guide
  mailbox, for every version: addressed to every voice, in the to-voices
  form, with the project's current commit and each voice's cut words from
  its latest turn (`src/035-to-voices.lua`, `input/to-voices`). The
  receipt counts the versions handed to rmail.
- **304, the turn hook on each voice** (2026-11-05): `scripts/turn-hook`
  (`src/037-turn-hook.lua`) leaves kuvalu's newest canvas waiting in
  `tmp/shared-memory/turn/<voice>/` and starts the turn runner unless it is
  running, printing nothing and returning at once. The runner
  (`src/038-turn-runner.lua`) holds a lock that no two runners can share
  and that a dead runner cannot keep, runs one turn at a time, always on
  the newest canvas, and sends each changed canvas back to the guide. The
  turn is a program named in `input/turn-runner`: phase 3's stand-in
  (`src/039-stand-in-turn.lua`) writes scripted words, and 405's real
  turn takes its place there.
- **305, the rehearsal** (2026-11-05): `scripts/rehearse`
  (`src/043-rehearsal.lua`) runs the whole round on kuvalu. Four mailboxes
  are made in RAM by the mailbox setup: the guide, and three stand-in
  voices with the turn hook and the stand-in turn. The blitter mails every
  version. Each voice turn is timed at eight points, from the version
  published to the voice receiving the version its turn made. The mail
  goes by rmail's own file-and-hook rules and timers, carried by
  `src/041-stand-in-carrier.lua` on this machine only. On the owner's
  machine, `carrier = "rmail"` runs real daemons instead. Rehearsing showed
  that rmail names the second and third voices' canvases
  `canvas-from-<voice>`. Both hooks now read that name.
- **306, the phase 3 demo** (2026-11-05): `issues/completed/demos/phase-3-demo`
  (also `./run-phase-demo 3`) runs the rehearsal for a few minutes with
  rmail's own timers.
  - Each version is drawn as it is made, with phase 2's marks, its voice,
    its turn and its round trip.
  - Then a timeline per voice, and a histogram of the round trips beside
    the part spent waiting for rmail's timer.
  - Then the canvases that waited and those replaced before use, and the
    rehearsal's receipt.
  - Every number is checked against the rehearsal's own records.

## Phase 3 is complete

All of phase 3's issues (301–306) are done, and the demo runs. On kuvalu,
canvases go round the guide mailbox and three voice mailboxes as living
messages. Each voice runs one turn at a time on the newest canvas, and
every leg of every round trip is measured.

The roadmap's last goal for phase 3, "the measured round trip through
real rmail", is met only under the stand-in carrier here. The stand-in
follows rmail's file-and-hook contract and its timers, but it is not rmail.

Left for the owner's machine:
- **Real rmail on kuvalu** (`carrier = "rmail"` in `input/rehearsal`),
  with the four daemons. Real encryption and real sync timing are measured
  only there. rmail's public-IP check has no off switch, so each daemon
  asks an outside provider for kuvalu's address (`docs/network.md` wants a
  switch).
- **The guide mailbox's daemon on port 1223**, and the router.
- **rmail and the turn hook on the fg-sora machines** (702, 704), with
  real endpoints (401a, 402).
- **The demo watched in a real terminal**, for its five minutes.

