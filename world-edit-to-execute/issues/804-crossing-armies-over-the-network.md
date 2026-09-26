# Issue 804: Crossing Armies, Drawn From Across the Network

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation (a demo)
**Priority:** Medium
**Dependencies:** 405f (units path around units), 803 (the messages, the server inside the client), 515c (the mailbox)

---

## Current Behavior

Built (2026-09-25); waiting on the owner to try the window.
`src/render/crossing/run-crossing.sh` builds and checks it:
- **A clean connection** (8 s): about 500 states, ticks only rising, no two
  units overlapping in any state, nothing refused.
- **100 ms delay, 60 ms jitter, 20% loss** (8 s): the same promises hold;
  about 115 states arrive after a newer one and are dropped.
- **Two pictures:** the armies weaving through the gap with their paths
  drawn, and the waiting dialog (the stand-in silent, the countdown to the
  vote, both sliders, the one in force marked).
- **Found on the way:** with jitter, messages overtake each other, and the
  first receiver published whatever came last; the picture jumped
  backwards 96 times in 8 s. The receiver now drops a state older than the
  newest it has shown, and the check counts ticks going backwards.
- The server now sends every player's slider when a pause begins, so the
  dialog opens with them.
- Paths messages lost on a lossy connection leave a unit's drawn path
  stale until its next re-plan; they are for drawing only.

## Intended Behavior

A raylib window showing two armies swapping sides through a gap, where
every unit routes around every other (405f), and every state drawn has
come from the server as bytes. The owner (2026-09-25): "Can we build a
render demo that displays this pathfinding? And maybe integrate it into
the network test somehow, even if it's just simulated?"

**The game:** `src/net/crossing_sim.lua` puts the arena (walls with a
gap, from `src/net/arenas/crossing.lua`) and two armies into the crowd, and
answers the server's three questions. When every unit has arrived or given
up, the armies are sent back.

**The renderer** (`src/render/crossing/`), with Lua built in (decided with
the owner, 2026-09-25):
- **The receiving thread** holds a Lua state that starts the server on its
  own thread (803's `hosted.lua`), sends this player's heard beats (and a
  second, stand-in player's), and hands every arriving message to C.
- **The C unpacker** is generated from the same message descriptions
  (`messages.lua`) by a tool, so the two sides can't drift apart. Unit
  states are written straight into the mailbox's writing buffer.
- **The draw thread** draws the arena from the map file (both sides read
  it, as a map file is shared in Warcraft III), each unit as a cylinder in
  its team's colour, each unit's path as a line, and the numbers.
- **The network, live:** keys add delay, jitter, loss to the connection,
  or silence the stand-in player; the waiting dialog (the silent players,
  the countdown, every player's slider, a vote button) is drawn over the
  paused game, and this player's slider is draggable.
- A **paths** message (server → client: unit, point number, x, y) carries
  each re-planned path, for drawing only.

**Modes, checked without anyone watching:**
- `--check SECONDS`: no window; every state received has no two units
  overlapping, ticks only go up, and every unit arrives or gives up.
- `--shot SECONDS PATH`: a picture after that long.

## Suggested Implementation Steps

1. The arena and `crossing_sim.lua`, tested through the server in Lua.
2. The C unpacker generator and its test (bytes encoded in Lua decode in C
   to the same values).
3. The receiving thread with Lua built in.
4. The window, the keys, the waiting dialog.
5. `--check` and `--shot`; a run script.

## Acceptance Criteria

- [x] `--check` passes with and without a disturbed connection
- [x] `--shot` shows the armies mid-crossing
- [ ] The window runs interactively (the owner confirms)
- [x] `.info.md` beside each new source file

## Related Documents

- `issues/405f-units-path-around-units.md`
- `issues/803-gameplay-messages-server-inside-the-client.md`
- `issues/completed/515c-mailbox-triple-buffer.md`
