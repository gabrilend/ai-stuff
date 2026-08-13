# 910 — Phase 9 demo: the capstone

## Current behavior

Issues 901 through 909 produce the full launch system. The MMU
protects apps from each other and from the kernel; per-app
queues drive the foreground/background/asleep distinction;
explicit close reclaims RAM. Phase 9 needs the capstone demo
the roadmap calls out: a fifth app written on-device, crashed,
repaired, run again — while the four launch apps stay running
in the background unaffected.

## Intended behavior

The demo is interactive and walks the developer through every
step. Scripted at
`issues/completed/demos/phase-9/run.sh`:

### 1. Set the stage

The script boots the device and confirms all four launch apps
are loaded: editor on bottom screen, messenger on top screen,
programming environment and paint program in background. The
script subscribes to the transcript ring's CDC-ACM stream and
collects a heartbeat event from each app — proof of life.

### 2. Author the fifth app on-device

The user (prompted by the script) opens the programming
environment and creates a new map called `coin-flip`. The map
has one read box (a button-down event source), one call box
that returns `"heads"` or `"tails"` based on a random byte, and
one debug-write sink. The map runs every button press: press a
button, see the result.

The user authors this entirely through the on-device editor and
the on-device programming environment — no laptop required. The
authoring exercises every piece of the editor (rendering, modes,
radial-menu chord input, save) and the programming environment
(canvas, Run, persistence).

### 3. Watch it crash

The user introduces a deliberate bug — for example, returning a
null pointer the next box dereferences. They run the map. The
MMU's fault handler (903) trips, the app fault recovery (904)
kills `coin-flip` cleanly, the banner appears on the screen
where `coin-flip` was foreground.

The script verifies: the four launch apps' heartbeats continued
without interruption through the crash. The kernel did not
reboot. Other apps' surfaces did not flicker.

### 4. Repair in place

The user follows the link from the banner back into the
programming environment, which received the fault context from
904. The fault context highlights the offending box. The user
edits the source, fixes the bug, saves. The compile pipeline (409)
compiles it and adds a catalogue row; 411 places a station on it and
moves the arrows across.

### 5. Run it cleanly

The user re-opens `coin-flip` (via 909's `app_open` triggered
by the link transition). The map runs. Button presses produce
heads or tails through `debug-write`. The script verifies the
output stream.

### 6. Confirm survival

Throughout all five steps, the four launch apps' heartbeats
keep flowing. The transcript ring is reviewed: no `app-faulted`
event for any launch app, no kernel panic events. Closing the
demo cleanly returns the screens to their original layout.

## What the demo proves

- The MMU protection model survives a user-authored crash.
- The launch apps are isolated from each other and from a
  buggy fifth app.
- On-device authoring closes the loop: edit, run, see error,
  fix, run again.
- The lifecycle transitions (close, open) reclaim and re-
  allocate cleanly.
- Compiling on the device, replacing a box by rewiring, and freeing
  the code nobody placed all function under live load — including the
  part that matters most, that a core parked with nothing to do does
  not stall the sweep.

## Suggested implementation steps

1. The script's narrative orchestration with developer prompts.
2. The heartbeat collection across the four launch apps.
3. The deliberate-bug example source for `coin-flip`.
4. Per-step pass/fail assertions on transcript events.

## Related documents

- `docs/002-roadmap.md` — phase 9 demo description.
- `docs/007-memory-model.md`.
- `docs/013-background-app-lifecycle.md`.

## Blocked by

All of 901 through 909.

## Closes

Phase 9. Closes the launch system.
