# 301 — boot the server with no data

*Route past the startup requirement instead of satisfying it. Gate off what
needs data; leave everything else running.*

| | |
|---|---|
| **Phase** | 3 — The Void That Boots |
| **Blocked by** | phase 1 (the patch machine must exist before a patch can) |
| **Blocks** | `302`, `303`, and every issue that wants to fabricate a table |
| **Tier** | PRE-BUILD source patches (`P###`), plus configuration |
| **Reversible** | required — the clone must round-trip clean |
| **Done when** | a client completes the login handshake and receives an empty character list |

---

## Current behaviour

The world server loads a large set of fixed-layout binary data tables during
startup and **exits** if they are missing. This is a refusal, not a degradation:
there is no partial mode, no warning-and-continue. The daemon does not reach the
point of opening its listening socket.

Those tables are normally extracted from a copy of the original game client.
There is no such copy and there will not be one — see
`docs/datapath-the-fabricated-data.md` for what that means and why it is the
position we want to be in.

The plan as written in that document was to generate the whole set before the
server would start. This issue replaces that plan with a cheaper one.

## Intended behaviour

**The server starts with no data tables at all**, announces exactly which
subsystems are switched off as a consequence, opens its socket, and completes
the protocol as far as the absence of a world allows — which is further than it
sounds.

The insight this rests on:

> Data is not needed by "the server." It is needed by *particular subsystems*,
> and those subsystems form a chain. No map means no world; no world means
> nothing can be standing in it; nothing standing in it means no character
> designs are needed. Cut the chain at the top and everything below it stops
> asking.

So the requirement becomes **a gate per subsystem** rather than one wall at the
front door. A closed gate does three things, and the third is not optional:

1. skips loading the tables that subsystem consumes,
2. disables the subsystem so nothing downstream calls into a hole,
3. **says so, at every startup, by name.**

Point three matters because a gate is a configured absence, not a fallback, and
the difference has to be visible. A server that quietly pretends to have a
feature it does not have is the failure mode this whole project is arranged to
avoid. The startup banner should read as an inventory: *these are off, this is
what they needed, here is the issue that opens them.*

### The first target, precisely

Not "a playable world." This:

```
   client                                          world server
     │◀─── AUTH_CHALLENGE ──────────────────────────│   it started
     │──── AUTH_SESSION ───────────────────────────▶│   it is listening
     │◀─── AUTH_RESPONSE  accepted ─────────────────│   it knows who we are
     │──── CHAR_ENUM ──────────────────────────────▶│
     │◀─── CHAR_ENUM  (empty list) ─────────────────│   it is talking
```

An empty character list is a **correct** answer for an account with no
characters. Nothing about that exchange needs a map, a race table, a display, or
a single row of world content. It is the whole of "running and talking," and it
is reachable with every gate closed.

### The order the gates open

Each is its own later issue. This one only establishes that they exist and are
closed.

| Gate | Needs | Unlocks |
|---|---|---|
| *(all closed)* | nothing | login, auth, empty character list |
| character definition | the race, class, and display tables | creating a character |
| world | a map row, terrain, a starting position | entering, standing, walking |
| collision | collision geometry | line of sight, standing on things |
| navigation | a navigation mesh | anything that walks by itself |
| content | items, creatures, interactables | a game rather than a room |

The shipped world content is **not** a dependency of any of these. It is a
reference for how the tables relate to one another, and nothing more — the
things in our world will be ours.

## Suggested implementation steps

**1. Read before patching.** Find where startup loads the data tables and where
it decides to exit. Two things to establish, both by reading rather than
guessing: whether the loader has a single decision point or one per table, and
whether any of this is *already* configurable. Anything reachable by
configuration is not a patch — a setting upstream deliberately provides cannot
conflict with upstream, and this is the same reasoning that prefers a module
hook to a source edit throughout the project.

**2. Inventory before gating.** Produce the map of table → consuming subsystem →
what breaks without it. This is the actual deliverable of the issue; the patch
is small once this exists. Expect the answer to be uneven — a few tables will
turn out to be load-bearing for things that look unrelated, and those are worth
finding now rather than at the moment a gate is opened.

**3. Gate the loader.** One anchored patch, or a small set. Standard component
shape from `docs/datapath-the-patch-machine.md`: a guard so re-applying is
inert, a unique marker so the inverse has a stable handle, a witness the probe
and the inverse agree on, and a declared match count the verifier asserts.

**4. Gate the consumers.** The loader skipping a table is not enough — whatever
would have read it has to be told, or it will reach into an absence. Prefer
disabling a subsystem at its entry point over defending every use.

**5. Make the absence loud.** The startup inventory described above. It should
be impossible to run this server and not know what is switched off.

**6. Establish what the databases still need.** The account and character stores
are structure rather than content and are presumably still required. Whether the
world content store must *exist* while being empty is a question to answer by
trying it, not by reasoning about it.

**7. Prove it with a conversation, not a log line.** "It started" is not the
success condition. The success condition is the exchange drawn above, driven by
the client from phase 2 extended just far enough to ask for a character list.

## What could go wrong

- **A subsystem assumes rather than checks.** Something reaches for a table it
  was never told is absent, and the failure lands far from the gate. This is the
  expected shape of trouble and the reason step 2 comes before step 3.
- **The gates are not independent.** If closing one forces another closed, the
  table above is a lie and needs redrawing. That is a finding, not a setback.
- **A patch that will not reverse.** The clone must round-trip clean. The
  verifier catches this before the patch enters the set; it is listed here
  because a gating patch touches startup code, which is the code most likely to
  be restructured upstream.
- **The gates outlive their usefulness quietly.** Once a subsystem's data is
  fabricated, its gate should open and its patch should be retired. The pruning
  machine will not catch that — it detects upstream movement, not our own
  progress — so the inventory from step 2 is the thing that has to be kept
  honest.

## Related

- `docs/datapath-the-fabricated-data.md` — what these tables are; **this issue
  changes that document's plan** and it needs updating to match
- `docs/datapath-the-patch-machine.md` — the component shape every patch here uses
- `docs/datapath-the-world-stream.md` — the exchange that defines success
- `docs/roadmap.md` — phase 3, and the questions still open against it
