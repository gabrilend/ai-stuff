# 305 — Rehearsal with stand-in voices on kuvalu

phase 3, the relay through rmail

## Current behavior

Voice canvases reach the blitter only by being dropped into its folder.

## Intended behavior

Three extra rmail mailboxes on kuvalu, in RAM, on spare local ports, named
`fg-sora-1`, `-2`, `-3`, made by the mailbox setup script (301). Each has
the guide mailbox as its contact and the turn hook (304), with the stand-in
turn, installed. Together they rehearse the whole round with real rmail, real
encryption and real sync timing before any mini-computer is set up.

It stays as the test bench for every later change. The real turn (405) and
distill mode (601) are first run here.

## Suggested implementation steps

1. A rehearsal script that makes the three mailboxes, starts their daemons,
   and tears them down on exit.
2. Measure, per voice turn: canvas received, turn finished, arrived on
   kuvalu, blitted, next version received back. These go to the log for the
   demo.

## Related documents

- `docs/datapath-round-trip.md`

## Blocked by

301, 302, 303, 304.

## Blocks

306, 405.

## Decisions (2026-11-05; each the owner's to overturn)

1. **A stand-in carrier plays rmail's part here, and real rmail is one
   setting away.** rmail needs LuaSocket, OpenSSL and its compiled
   helpers. This project installs nothing, so `src/041-stand-in-carrier.lua`
   carries the mail by rmail's own file-and-hook contract, read from rmail
   main and #215:
   - outbox and inbox files, and rmail's inbox names;
   - `on_receive` in the background;
   - `on_update` waited for, with the body on stdin as well, its output
     kept, and its failure refusing the edit;
   - the sender known by token;
   - per-contact timers.

   It lives in guide-feature, and r-mail is not changed.
   `carrier = "rmail"` in `input/rehearsal` starts a real daemon for each
   mailbox instead. That is the owner's to run (below). "Real encryption
   and real sync timing", as the issue puts it, come only with that.
2. **The carrier reaches only this machine.** A contact whose `ip` is not
   127.x or localhost is reported and not carried, so the rehearsal can
   never send anything off kuvalu.
3. **Its timers are rmail's, with rmail's numbers in `input/rehearsal`**
   (30 s ± 30 s). Every contact is due at the start. A contact is due
   again after the floor plus the jitter. A contact that has just
   delivered to a mailbox is due at once there. The demo's histogram
   therefore shows rmail's own pacing. The test uses 1 s ± 0.5 s.
4. **Everything is made in RAM, in `tmp/shared-memory/rehearsal/`.** It
   holds a copy of the project (src/, libs/ and scripts/ linked, its own
   `input/` and RAM tiers), so a blitter already running on kuvalu is not
   touched, and the four mailboxes on ports 41223–41226. The mailboxes are
   made by `scripts/make-mailboxes` from a set the rehearsal writes, as
   the issue asks. The workspace is removed at the end, by the program and
   again by `scripts/rehearse`'s exit trap.
5. **The blitter runs inside the rehearsal**, with the to-voices
   publisher and one that times every version. That way "published" and
   "blitted" are timed to the millisecond. The hooks and turn runners are
   separate processes, as on the real machines.
6. **Eight times per voice turn**, from the voices' event files (304), the
   carrier's deliveries and the blitter: published, received, taken,
   finished, delivered, arrived, blitted, back. Each turn is one line in
   `tmp/shared-memory/rehearsal-timings`; every event is in
   `rehearsal-events`; the per-voice counts are in
   `output/goodbye-rehearsal`.
7. **A canvas sent but never carried is `superseded`.** A voice whose
   next turn ended before its timer came round sends only its newest
   canvas, since only the newest version of a living message travels.
   That is how rmail is meant to be used here. A canvas still travelling
   at the end is `in-flight`.
8. **Runners and daemons are stopped by process group** (they are
   started with `setsid`), so a turn running at the end stops with its
   runner.
9. **Fixes found by rehearsing:** the hooks read rmail's
   `canvas-from-<sender>` inbox names (302 and 304 notes), and the stand-in
   turn no longer repeats itself (304 note).

## Implementation notes (2026-11-05)

- `src/041-stand-in-carrier.lua` and `src/042-test-stand-in-carrier.lua`
  (28 pass).
- `src/043-rehearsal.lua`, `scripts/rehearse`, `input/rehearsal`, and
  `src/044-test-rehearsal.lua` (21 pass), which runs the whole round for
  twenty seconds.
- `src/033`, `src/037` and `src/039` changed, as above; 034 and 040 gained
  checks.
- Mutation checks, all caught: 15 on the carrier, 6 on the rehearsal
  (not mailed, blitted not timed, back not found, superseded never named,
  runners not stopped, waited miscounted). The last two needed new checks
  first: a slow on_receive, and the waited count redone from the events.
- `docs/datapath-round-trip.md` ("The rehearsal"),
  `docs/rmail-constraints.md`. `.file-index-counter` is at 044.

**Needs the owner's machine:** the rehearsal with `carrier = "rmail"` on
kuvalu, with rmail installed (its command in `input/rehearsal`), to see
real encryption and real sync timing. Its public-IP check has no switch
(rmail `check_public_ip`), so the four daemons will each ask a provider
for kuvalu's public address. That is the owner's to allow.
