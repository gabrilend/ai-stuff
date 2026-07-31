# architecture

*The shape of a server we did not write, a client we did, and the machine that
holds the two of them apart until they are ready to become one project.*

---

## The one-paragraph version

An existing open-source server that emulates a well-known online game is cloned
fresh on every build and never committed. A directory of small reversible
scripts stamps our changes into that clone, the build happens, and the changes
are peeled straight back off — so the clone always round-trips to a pristine
copy of upstream. Against that server we write our own client, in C, which
speaks the authentic wire protocol from its very first run. There is no copy of
the original client anywhere in this, so everything that server expects a client
to have provided is either generated — from schemas read out of the server's own
source — or gated off until something actually wants it, which is how the first
world is a featureless void that boots and talks. Then, one gate and one patch
at a time, a game is *selected* out of what is there: nobody is handed an
ability, the ground becomes squares and triangles, the players become pink star
squiggles, and everything unreached stays present and silent. An original client
should still be able to connect to that void and hold a conversation, because a
second implementation of the format is the only thing that can tell us we are
wrong. It is not done until our own client can do it instead.

---

## The three bodies

There are exactly three trees of code in this project, and they have three
different relationships to us. Confusing them is the main way this design can
go wrong, so they are named apart:

| Tree | Who wrote it | Tracked in git? | Lifetime |
|---|---|---|---|
| `upstream/azerothcore/` | someone else | **no** — gitignored | wiped and re-cloned at will |
| `patches/` | us | yes | permanent; this is the real source of truth |
| `src/` | us | yes | permanent; our client and, eventually, our engine |

The middle row is the project. `upstream/` is a *deterministic function* of an
upstream commit hash and the contents of `patches/`, which means it can always
be thrown away and recomputed. `src/` is ours outright and owes upstream
nothing but a packet format.

The directory is called `upstream/` and not `source/` on purpose: `src/` and
`source/` sitting side by side in a listing is a trap, and this project has one
of each concept.

---

## Why the server is not forked

The two obvious ways to change code you do not own both rot.

**Editing in place** means every upstream pull either clobbers your work or
silently keeps it, and within a month nobody can point at which lines are
yours. **Maintaining a hard fork** means every upstream update is a merge
conflict across a diff that grows until "what did we change, and why" stops
having an answer.

The third path: version the *intent*, regenerate the *result*. Each thing we
want changed about the server becomes a pair of shell functions —

    apply:    pristine tree    →  customized tree
    unapply:  customized tree  →  pristine tree      (exact inverse)

— and the build composes them:

```
reset the clone to upstream HEAD      ⟶ guarantees a known starting tree
audit the patch set against the delta ⟶ flags patches upstream moved under
apply the profile's patches           ⟶ customizations present
trap 'unapply' EXIT                   ⟶ revert happens even if the build dies
build                                 ⟶ compile the customized tree
install to staging                    ⟶ binaries land where they can be checked
unapply, explicitly                   ⟶ clone is pristine again
record the upstream commit            ⟶ baseline advances only on success
```

Two properties are asserted mechanically rather than trusted. **Idempotency**:
apply checks for the un-patched pattern before editing, unapply checks for the
post-patch marker, so running either twice is inert. **Exact inverse**:
`apply → unapply → git diff` must be empty, and a harness refuses to admit a
patch that fails it.

The payoff for this project specifically is that an upstream release stops
being a crisis. Re-clone, re-apply; a patch whose anchor upstream deleted fails
loudly and names itself. One patch to re-target, not a fork to reconcile.

`docs/datapath-the-patch-machine.md` has the full mechanism.

### Prefer the seam upstream already cut

AzerothCore ships a first-class module system: a `modules/` directory whose
contents register against script hooks the core deliberately exposes — hooks
that fire on player login, on creature death, on gameobject use, and a few
hundred other moments. Code that lives there is not a patch at all; it is an
extension the core is designed to accept.

**A registration cannot conflict.** Anything achievable through a module hook
is done as a module, and only what has no hook becomes a patch against core
source. This ordering is not a style preference — it is the difference between
a change that survives an upstream refactor untouched and a change that has to
be re-anchored every time the surrounding function moves.

So the selection work of phase 6 splits in two before it starts: *what can be
done from outside* (a module that hands nobody a spell) and *what requires
reaching in* (anything with no hook near it).

---

## Why the client speaks the old protocol first

The vision wants liberation from "a single client on the internet we found."
The tempting reading is to strip the server's packet layer down to something
clean before writing any client, so the client never has to learn a format it
is going to throw away.

We are doing the opposite, and the reason is regression, not nostalgia.

A client that connects to **unmodified** upstream on day one is a working
baseline. Every patch written afterward is then checkable against something
that already ran: the client either still logs in and walks, or it names the
patch that broke it. Without that baseline, the first ninety patches are
unverifiable — nothing runs end to end until both halves are simultaneously
finished, and every bug is ambiguous between the two of them.

```
day 1    our client ──authentic protocol──▶ stock server         ✓ walks
day 30   our client ──authentic protocol──▶ fabricated world     ✓ still walks
day 90   our client ──protocol + our own─▶ a server, configured  ✓ arrived
```

Whether the protocol is eventually replaced is left open — *"I never said
never"* — but it is not a goal, and there is a property being held on purpose in
the meantime:

> **An original client should be able to connect to us and talk, standing in a
> blank featureless void.** And ideally in whatever we manage to build after
> that, too.

That is worth holding for a reason beyond sentiment. A real client is an
**independent implementation of the format**, written by people who had the
specification, and it will disagree with us wherever we are wrong. Nothing else
available gives a second opinion about whether our server is correct. It is the
only oracle in the project that we did not also write.

The completion criterion is the other direction and is not negotiable: **there
is a custom client before any of this is called done.** Compatibility is a
property we keep because it is useful; our own client is the point.

The client also gets to be radically incomplete. It needs enough of the
protocol to log in, enumerate characters, enter a world, move, click a thing,
receive other players' movement, and read its own inventory. That is a few
dozen message types out of roughly fifteen hundred. Everything about combat,
spellcasting, chat channels, guilds, auctions, mail, battlegrounds, and pets is
simply never implemented. Those systems stay alive on the server, unreached and
silent, which is what makes the omission a decision that can be revisited rather
than a door that has been bricked up.

---

## The two halves of our own code

Generation and viewing stay separated, as they do in every project here. The
seam is drawn at a different place than usual, because the "generator" is a
server across a socket:

```
                    ┌─────────────────────────────────┐
   the socket  ────▶│  net/    protocol in, bytes out │  knows sockets, crypto,
                    │          no idea what a whisp is│  and packet layout
                    └────────────────┬────────────────┘
                                     │ world events
                                     ▼
                    ┌─────────────────────────────────┐
                    │  world/  entities, positions,   │  knows what exists and
                    │          inventory, the timer   │  where; no idea there
                    └────────────────┬────────────────┘  is a screen
                                     │ a snapshot, per frame
                                     ▼
                    ┌─────────────────────────────────┐
                    │  draw/   geometry, palette,     │  knows GL; no idea a
                    │          camera, squiggles      │  socket exists
                    └─────────────────────────────────┘
```

The arrows only point down. `net/` never asks what is on screen; `draw/` never
sends a packet. The middle layer is the only thing that knows both a byte
stream and a world exist, and it holds no GL state and no socket.

The immediate practical payoff is that the entire lower half runs headless.
Phases 2 and 3 produce a program with no window at all that logs in, walks a
character in a circle, and prints what it sees — which means the protocol work
is finished and proven before a single triangle is drawn, and a rendering bug
can never be confused for a networking bug.

The second payoff is replay. Because `world/` is fed by events rather than by a
socket, the same events can come out of a recorded packet log, and `draw/` is
none the wiser. A session becomes reproducible without a server running.

---

## What the world looks like

The vision asks for abstract geometry, and names four schemes:

| Background | Colours |
|---|---|
| white | bright |
| black | bright |
| blue | muted |
| green | muted |

The terrain is squares and triangles. Flat-shaded, untextured, hard-edged. The
entire art budget is vertex positions and a colour index, which is why a
hand-written renderer is a reasonable thing to attempt at all — there is no
asset pipeline to build, because the assets are numbers.

**The inhabitants are the exception, and this is the visual thesis.** A player
is a pink star squiggle: a radial burst whose arms wander rather than hold
still, dragging a hand-drawn trail behind it as it moves. Pink appears in none
of the four schemes. The star is the only radial form in a world of right
angles. The squiggle is the only curve.

    world:  ▲ ■ ◣ ■        rigid, one of four schemes, straight edges
            ■ ◤ ▲ ■

     you:      ✳ ~~~~,     pink, radial, wandering, always the exception

So: rigid terrain, soft inhabitant. A player never has to hunt for themselves
on screen, because they are the only thing in the frame that is not made of
straight lines. `docs/datapath-the-whisp.md` is how the squiggle is actually
generated; `docs/datapath-the-world-of-shapes.md` is the terrain and the
schemes.

---

## What the gameplay is — selection, not amputation

Stated as verbs, because the vision states it as verbs:

- **move to a location** — click the ground, the whisp goes there
- **click on a thing** — the one interaction verb
- **wait until the thing is done** — a timer, visible, interruptible by moving
- **drink a potion** — consumable use
- **wear better equipment** — item equip, stats apply

That is what the game *is*, right now. It is not what the server is capable of,
and the difference matters more than it looks:

> *"Assume that all the functionality is requested eventually, but we will only
> use some of it. I don't know what 'some' yet though."*

So the narrowing is **selection, not deletion.** The server keeps its systems.
What changes is what a player is granted, what the client exposes, and what the
world contains. "No abilities" means nobody is given an ability and the client
has no button for one — not that the code which would have run them is torn out.

Three reasons this is the better shape, and the third is the real one:

- **It is reversible.** A system nobody uses costs a little memory. A system
  that has been surgically removed from a large C++ codebase costs a month to
  put back, and the month is spent finding what else came out with it.
- **It survives upstream.** Deletions are the most fragile patches possible —
  they conflict with every refactor of the thing they delete. A configuration
  that grants nothing conflicts with nothing.
- **The subset is not known yet, and pretending otherwise is the expensive
  mistake.** "I don't know what some yet" is the honest state of the design.
  Building a machine that can only do the currently-imagined subset would mean
  discovering the next want as a rebuild rather than as a switch.

The one thing that *is* removed is exposure. The client implements what it
needs; the world grants what it should. Anything unreached stays present and
silent, and the day it is wanted, it is wanted from a working server.

The tension that would have existed here dissolves accordingly: "wait until the
thing is done" is, upstream, a *spell* — gathering is a cast-time spell and the
cast bar belongs to the spell system. Under deletion, those two asks fight.
Under selection they do not: the spell system stays, gathering works exactly as
it always did, and the reason a player cannot fire a bolt of lightning is that
nobody ever handed them one.

---

## No client data, which turns out to be the stronger position

There is no copy of the original client, and there will not be one.

This matters more than it first appears, because the world server does not
*degrade* without the client-derived data tables — it refuses to start. About a
hundred fixed-layout binary tables, plus terrain grids per map, are a hard boot
requirement. So they get fabricated.

The vision asked for exactly this, in its own word:

> *"…liberate it from being bound to a single client on the internet we found."*

A server fed with extracted retail data is still bound to that client; it just
holds the binding at one remove, in a directory of files somebody else's program
produced. A server fed data we generated is not bound to it at all. There is no
copy of anything, anywhere in the pipeline. Being unable to obtain the data
forced the more complete version of what was already wanted.

Three things make it tractable:

**The schema is in the tree we already clone.** The server's own loading code
declares the layout of every table it reads — the format descriptor *is* the
schema, in the strongest sense, because it is what will actually be applied to
our bytes. Nothing is transcribed; an extractor reads it at build time. This is
the third appearance of that pattern (opcodes, cipher constants, table layouts),
and it is now `strategems/the-upstream-tree-is-the-schema.md`.

**The world database was never client data.** Creatures, items, quests, spawns,
starting positions — all of it ships as SQL alongside the server source. We are
not reconstructing a game; we are producing the tables and terrain grids the
server reads before it will agree a world exists.

**Flat ground is nearly free, and the hard artifact is not written at all.** The
height format carries a flag meaning *this tile is flat at one height*, under
which there is no grid to generate. Collision and pathfinding are each
switchable off in the server's own configuration and are not needed to stand and
walk. When collision does arrive, the navigation mesh comes free — it is built
by a tool that ships with the server, consuming height and collision data, so
producing those two correctly is the entire job.

The map format itself stays the game's own, which is what keeps that toolchain
usable and leaves us free to build whatever we want on top of it later. And
because the collision file is a triangle soup and our renderer wants triangles,
**both halves read the same files** — what you see is what you collide with, not
by synchronisation but because there is no second copy to drift from.

`docs/datapath-the-fabricated-data.md` carries the mechanism;
`docs/datapath-the-world-of-shapes.md` carries what the geometry becomes.

---

## Where the pieces live

```
   notes/vision ───────────────────────────────────────────── the ask
        │
        ▼
   upstream/azerothcore/  ◀── cloned fresh, gitignored, disposable
        ▲       │
        │       │  its headers are read, not copied:
        │       ├──────▶ opcode numbers ┐
        │       ├──────▶ cipher seeds   ├─▶ generated, never transcribed
        │       └──────▶ table layouts  ┘
        │
        │  patches/   apply → build → unapply, exact inverse, verified
        │  modules/   the seam upstream already cut; preferred
        │
        ▼
   authserver (port 3724)          worldserver (port 8085)
        │                                │   ▲
        │  SRP6 login                    │   │ reads the fabricated
        │                                │   │ tables and terrain
        │            input/world/*.shape ────┘
        │                  │             │
        │                  │  tools/fabricate
        │                  ▼             │
        │            .map · .vmap · .mmap│  RC4-encrypted packet stream
        │                  │             │
        ▼                  ▼             ▼
   ┌──────────────────────────────────────────────┐
   │  src/   our client, in C                     │
   │    net/  ─▶ world/ ─▶ draw/                  │
   │    reads the SAME terrain files as the server│
   │    SDL2 for the window, OpenGL to draw       │
   └──────────────────────────────────────────────┘
        │
        ▼
   output/   ── written last; where goodbye goes
```

Note what is not in the diagram: any file that came from somewhere else. The
clone is regenerated from a commit hash, the tables and terrain are generated
from `input/` plus the clone's own schemas, and the opcode table and cipher
constants are extracted at build time. Nothing in the repository is a copy of
anything.

## Related

- `docs/roadmap.md` — seven phases, and the open questions each one carries
- `docs/datapath-the-patch-machine.md` — clone, apply, build, revert, audit
- `docs/datapath-the-handshake.md` — SRP6, and proving a password without one
- `docs/datapath-the-fabricated-data.md` — the tables and terrain no client gave us
- `docs/datapath-the-world-stream.md` — header encryption, opcodes, update blocks
- `docs/datapath-the-whisp.md` — how a pink star squiggle is made
- `docs/datapath-the-world-of-shapes.md` — the authoring format and the four schemes
- `strategems/the-upstream-tree-is-the-schema.md` — the extraction pattern, three times
- `docs/table-of-contents.md` — every document, indexed
