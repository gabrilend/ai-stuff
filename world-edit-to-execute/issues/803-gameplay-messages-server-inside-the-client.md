# Issue 803: Gameplay Messages, with the Server Inside the Client

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** 401 (the fixed-rate game loop), 515c (the mailbox the client's states arrive in)
**Related:** 804 (the first renderer fed by it), 515d (drawing late states), 801 (matchmaking; finds the host this connects to), W08 (the WoW-protocol server, which also carries time as ticks)

---

## Current Behavior

Being built (2026-09-25).
- **Step 1, the messages: built.** `src/net/messages.lua` describes all ten
  messages as data and encodes and decodes any of them;
  `src/tests/test_net_messages.lua` passes (every message round-trips and
  re-encodes to the same bytes; bad input is refused with a reason). A unit
  record is 38 bytes on the wire.
- **Step 2, the server's rules: built.** `src/net/server.lua` (plain
  logic, driven by whoever runs it) with `src/tests/test_net_server.lua`
  passing: ticks, orders and their answers, the pause and resuming with
  nothing rewound, the strictest slider in force, and the drop vote. A vote
  on oneself is refused before any other check.
- **Step 3, the server on its own thread: built.** `src/net/hosted.lua`
  runs the server on an effil thread; each player has a queue each way
  (`src/net/link.lua`), which can delay, jitter, lose, or go silent for a
  span. `src/net/circling_sim.lua` is a stand-in game whose units move as
  the renderer's ceramic test units do; `src/net/clock.lua` is the shared
  clock. `src/tests/test_net_hosted.lua` passes in real time: a clean
  connection, 100 ms of delay, half the messages lost, and a 1.3 s drop
  that the 2 s starting tolerance rides out and a 0.5 s slider turns into
  a pause resuming from the paused tick. All three test files run from
  `src/tests/run-net-tests.sh`.
- **Encoding speed:** 2,048 units encode in about 1 ms (a reused byte
  buffer, field names spelled out only on a refusal); the first version
  took 9.6 ms. Decoding into Lua tables takes about 1.7 ms, so the
  renderer's receiver should decode in C straight into the mailbox.
- **Found by the strict encoder:** the real clock has fractions of a
  millisecond, and the waiting message's times are whole; the server now
  rounds them, with a test.
- **Step 4, how the renderer receives: decided with the owner
  (2026-09-25): Lua built into the renderer.** A receiving thread in the C
  program holds a Lua state running the server on its own thread, as the
  tests do; a C unpacker generated from `messages.lua` writes states into
  the mailbox. Chosen over a separate server program on a local socket,
  which would make offline play two programs. Built as part of issue 804
  (the crossing-armies demo).
- Step 5: not yet (a refused order cancelling a local answer needs the
  client side).

Before this, there was no network code in the project (no sockets, no
protocol for play; 801 stops at the lobby). The simulation
(`src/runtime/`, the 62.5-ticks-a-second game loop and its systems) runs
in the same process as whatever reads it, with no line between "server"
and "client".

Decided with the owner (2026-09-25), recorded in
`docs/wc3-engine-architecture.md` (Multiplayer Strategy) and issue 515
(point 4):
- **One server holds the truth; lockstep is dropped.** The owner: "let's
  drop entirely. I see little benefit except for simulation accuracy. If
  that becomes a concern later, if we want that feature, we can build it
  then."
- **The client shows what arrives,** guessing forward only while the next
  state is overdue, up to a cap, then running in place (515d).
- **A silent player pauses the game for everyone,** as Warcraft III did,
  chosen over rewinding the game to meet a lagging player halfway (which
  gave the lagger an undo button and made everyone else watch the game run
  backwards). The owner: "let's do alternative number 2, since it's
  familiar, and a decent system."

## Intended Behavior

The messages between the server and its clients, built and tested first
with the server running inside the client (offline play, and every test),
so a real network later only replaces how the bytes travel.

**Time is ticks.** Every message that depends on timing carries a tick
number (32-bit unsigned, at 62.5 a second), never clock time, as in W08.

**The messages** (encoded to bytes even in-process, exactly as they'd go
over a network, so nothing is shared by pointer):

| Direction | Message | Carries |
|---|---|---|
| client → server | order | an order id the client chose (32-bit), the units, the kind, the target, the client's tick when given |
| client → server | heard | the newest tick the client has received (every client sends at least this each tick; it's how the server knows a player is there) |
| server → client | order answer | the order id, accepted or refused, and the tick it takes effect: what lets a client's local answer be kept or cancelled |
| server → client | unit states | the tick; for each unit that player can see: id, position, velocity, facing, animation and its phase |
| server → client | events | deaths, spawns and the like, each with the tick it happened |
| server → client | waiting | who the server hasn't heard from, and the time left before they may be dropped; or that play has resumed |
| client → server | tolerance | the seconds of silence this player will put up with before the game pauses (their slider) |
| server → client | tolerances | every player's slider value, and the one in force (the lowest) |
| client → server | drop vote | the silent player this player votes to drop |
| server → client | votes | the drop votes cast so far, per silent player |

**Waiting for a player:**
- The server tracks, per player, the tick it last heard from them.
- A player silent past the **tolerance in force** pauses the simulation for
  everyone. The server keeps sending "waiting" (the silent players, a
  countdown).
- When the silent player is heard again, play resumes from the tick it
  paused on; nothing is rewound.
- When the countdown ends, the others **vote** to drop the silent player
  (the owner, 2026-09-25: "vote"). The countdown runs **30 seconds**.
- **A drop needs three quarters of the players still connected, rounded
  down** (the owner, 2026-09-25: "3/4th of the players still connected,
  rounded down"), **and at least one vote**: with one player left, three
  quarters rounds down to zero, which would drop the silent player with
  nobody asking. Two players left need 1 vote, three need 2, four need 3,
  eight need 6.
- The client draws a waiting dialog over the paused game.

**Each player's tolerance** (the owner's design, 2026-09-25):
- The waiting dialog has a slider per player: their "desired network
  tolerance", in seconds of silence before the game pauses. It appears
  **only on the waiting dialog** (the owner, 2026-09-25), so until a
  player first moves it, theirs is the starting value.
- **The range is 0.25 to 10 seconds, starting at 2 seconds.** The owner
  (2026-09-25): "pick reasonable numbers and we'll adjust if necessary."
  0.25 s is about four missed ticks' worth of messages beyond ordinary
  jitter; 10 s is long enough to ride out a router restart's first
  moments. Later changes to these go in `docs/balance-updates.md`.
- Stricter means more "waiting for player" pauses; looser means more lag
  shown in play (units guessed forward, then running in place) and fewer
  waits.
- **The server uses the lowest value,** so the strictest player decides.
- **Every player sees every other player's value,** so whoever is making
  the game pause is visible.
- This answers what the pause limit is: the players' choice, separate from
  515d's cap, which measures the connection's jitter. A loose tolerance on
  a jittery connection shows units running in place for a while before any
  dialog appears; that is the trade the slider offers.

**The client side:** a receiver decodes states and writes them into the
mailbox's writing buffer (it replaces the renderer's feeder of 515c);
the draw thread is unchanged.

**The server inside the client:** the simulation on a thread of its own,
the two sides joined by in-memory message queues. An optional disturbance
between them (delay, jitter, loss, a player going silent) makes 515d and
the waiting dialog testable without a network.

## Suggested Implementation Steps

1. The message encodings, with a round-trip test for every message.
2. The server loop: orders in, the simulation's tick, states and events out,
   "heard" tracking and the pause.
3. The in-memory transport and its disturbance.
4. The client receiver into the mailbox.
5. Tests: an order answered and taking effect on its tick; a refused order
   cancelling a local answer; a silent player pausing everyone and resuming
   with nothing rewound; the lowest tolerance being the one in force; a
   player dropped by vote.

## Decisions

- Who may drop: a vote, needing three quarters of the players still
  connected, rounded down, and at least one vote.
- The pause limit is not 515d's cap: it's the players' tolerance.
- The slider lives only on the waiting dialog; 0.25 to 10 seconds, starting
  at 2; the countdown before a vote is 30 seconds (numbers picked, to be
  adjusted).

## Acceptance Criteria

- [ ] Every message encodes and decodes to itself
- [ ] Offline play runs through the messages, the server in its own thread
- [ ] The tests in step 5 pass, including under the disturbance
- [ ] `.info.md` beside each new source file

## Related Documents

- `docs/wc3-engine-architecture.md` (Multiplayer Strategy)
- `issues/515-render-graph-on-the-ceramic-engine.md` (point 4)
- `issues/515d-extrapolate-predict-snap.md`
- `issues/W08-our-own-server-speaking-the-same-protocol.md` (time as ticks)
