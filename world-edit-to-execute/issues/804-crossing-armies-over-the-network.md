# Issue 804: Crossing Armies, Drawn From Across the Network

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation (a demo)
**Priority:** Medium
**Dependencies:** 405f (units path around units), 803 (the messages, the server inside the client), 515c (the mailbox)

---

## Current Behavior

Nothing of this exists. The server can run on its own thread (803) but
only its stand-in game (circling units); the raylib renderer (515c) draws
states worked out by the ceramic engine, not received from a server.

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

- [ ] `--check` passes with and without a disturbed connection
- [ ] `--shot` shows the armies mid-crossing
- [ ] The window runs interactively (the owner confirms)
- [ ] `.info.md` beside each new source file

## Related Documents

- `issues/405f-units-path-around-units.md`
- `issues/803-gameplay-messages-server-inside-the-client.md`
- `issues/completed/515c-mailbox-triple-buffer.md`
