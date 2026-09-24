# Issue W08: Our Own Server, Speaking the Same Protocol

**Phase:** W - WoW Client Bridge
**Type:** Design Research (decides whether and how to build; no code yet)
**Priority:** High (it decides the licence of the whole stack)
**Dependencies:** W02 (what WC3 maps need from a server), W04 (the recording rig, reused for servers)

---

## Current Behavior

Converted WC3 maps are planned to run on AzerothCore (AGPL v3), with their
triggers as Lua scripts inside ALE (GPL v3). The projects are moving to the
owner's RGPL, which is being written. The RGPL draft deliberately does not
allow combining with GPL v3 code, and AGPL v3 forbids adding the RGPL's extra
clause, so RGPL code cannot be combined with AzerothCore or ALE.

## Intended Behavior

The owner (2026-09-23): "If AGPL isn't compatible with RGPL, then we might have
to just not bundle Azerothcore, and instead extract from it like we do with the
client, and re-create our own system that accomplishes the same tasks, but our
own design. We could even make it a soramech to ensure that it's fully
distanced, yet compatible, because it speaks the same protocol and uses the
same correctness standards."

### Two stages

**Stage 1 (now, no new server): AzerothCore is installed, not bundled.**
Like the Blizzard client, AzerothCore is something the user installs
separately; the RGPL projects never contain or link its code. The W client
talks to it over the network, and the converter writes files for it. The only
code that must run *inside* it (W02e's native shim and any server module)
stays under AGPL v3 in its own folder. A new Lua engine is **not** needed for
this stage.

**Stage 2: our own server.** A server of our own design that speaks the same
3.3.5a protocol, so the W client (and the stock client) can connect to it,
built as a **soramech map**: C leaf boxes (sockets, SRP6, packet codec, the
simulation step) wired by a map file that says what feeds what. An entirely
different architecture from AzerothCore's, which is the "fully distanced"
part. It uses the same correctness standard: for the same packets in, the same
packets out.

### The convergence this opens

With our own server, the rules engine for WC3 maps no longer has to be a
translation into someone else's scripting API. It can be **this project's own
simulation** (phase 3's JASS → Lua triggers, phase 4's game loop, pathfinding
and collision), running on the server. The 2026-09-23 decision ("the server
runs the rules") still holds, but the server runs the rules as the map wrote
them. The W02e shim becomes a stage-1 bridge only.

### How it is built without copying (clean-room, as in W05d)

| Role | Sees AzerothCore? | Produces |
|------|-------------------|----------|
| Describer | yes: runs it, records its traffic, may read its code | a **protocol and behaviour specification**: packet layouts, opcode meanings, handshake steps, the order and timing of server responses for each scenario |
| Builder | **never reads AzerothCore's code** | the soramech server, from the specification |
| Checker | runs both servers | **differential tests**: the same recorded client session replayed against AzerothCore and against ours; the packet streams compared field by field |

Packet layouts and opcode numbers are interface facts; the specification
states them as facts, without AzerothCore's code. Where possible the
describer works from recorded traffic rather than source.

### Time is carried as frames (decided 2026-09-23)

The owner: "all timing dependent things should include the frame when they
are expected to be applied. If it's in the future, we schedule it. If it's in
the past, we fast forward it. These rules should be hand written. For this
aspect, we prioritize sane design over correctness."

- **Frame** = one simulation tick of the phase 4 game loop (62.5 ticks per
  second, 16 ms each), counted from the start of the game. Type: uint32.
- **Every timing-dependent message between our server and the W client
  carries the frame at which it takes effect**: a move order, a unit's path
  step, an attack's hit, a spell's cast start and its landing, a buff's
  expiry, a death. Messages that don't depend on timing (chat, a name lookup)
  carry none.
- **Receiving a message for a future frame:** schedule it; apply it when the
  local frame counter reaches that frame.
- **Receiving a message for a past frame:** fast-forward it: apply it now, in
  the state it would have reached had it arrived on time (a unit ordered to
  move 5 frames ago appears 5 frames along its path; a hit that landed 3 frames
  ago has already taken its health).
- This is a sane rule, not an exact copy of how AzerothCore or the stock
  client time things. Where they disagree, ours wins.

**How the checker compares against AzerothCore.** AzerothCore doesn't send
frames; it sends millisecond times and durations. The checker converts each
of its timed packets to a frame with **hand-written rules, one per packet
type** (for example: a movement spline's start time → the frame containing
it; a damage packet → the frame it was received in). Two streams then match
when every timed event lands on the same frame. Differences that aren't about
game state (object ids, timestamps, the order of packets within one frame) are
listed per packet type in the same rules file and ignored. The rules are
written by hand and reviewed, not learned from repeated runs.

### Scope: only what WC3 maps need, first

Auth (SRP6) and realm list; world session crypto; character enter/leave;
creature spawn, movement and despawn; orders (move, attack, stop); combat and
damage; a small set of spells for converted abilities; chat. Everything else a
full WoW server does (quests, loot tables, professions, dungeons, guilds) is
out of scope until wanted.

### What "extract from it" means

Like the client: we don't redistribute AzerothCore, we read it. The
describer's specification and the recorded sessions are our artefacts; the
running AzerothCore is a reference to compare against, installed by whoever
runs the comparison.

## Suggested Implementation Steps

1. Record reference sessions against a stock AzerothCore (login, enter world on
   a converted map, move, attack, cast, chat, log out) with packet captures.
2. Describer writes the protocol/behaviour specification per session.
3. Soramech box catalogue for the server: which leaf boxes, which maps.
4. Builder implements auth first, then world session, then each scenario.
5. Checker replays each recorded session against both and reports differences.
6. Decide the switch-over: the stage-1 shim is retired when every W02 scenario passes on our server.

## Acceptance Criteria (for this research issue)

- [ ] The staged plan accepted or changed by the owner
- [ ] A list of the reference sessions and the scope above confirmed
- [ ] A sketch of the soramech box catalogue for auth and world session
- [ ] Implementation issues created from this design

## Open Questions

1. Confirm stage 1: AzerothCore installed separately, the shim under AGPL v3 in its own folder, until our server exists?
2. Is the soramech runtime ready to host a network server (sockets, long-lived connections, per-connection state), or does this wait on the soramech project?
3. Does our server need its own database at all, or can a converted map's rows live in files loaded at start (the world database was going to hold only what the map needs anyway)?

## Related Documents

- `docs/licensing-and-boundaries.md`
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (W02e shim, W02h empty world database)
- `issues/W05d-clean-room-describe-build-check-loop.md` (the clean-room roles)
- `/mnt/mtwo/programming/ai-playground/minimal-soramech/README.md` (what a soramech is)
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/004-network-protocol.md`
