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
speaks the authentic wire protocol from its very first run. Then, patch by
patch, the server is narrowed: abilities go, most of the verbs go, the maps
become squares and triangles, and the players become pink star squiggles. When
the narrowing is far enough along that the original protocol is mostly dead
weight, the client and the server stop being two projects that agree on a
format and become one project that has an inside.

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

So the narrowing work of phase 5 splits in two before it starts: *what can be
done from outside* (a module that refuses to let spells be cast) and *what
requires reaching in* (a terrain loader taught to read a format that did not
exist when it was written).

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
day 1    our client ──authentic protocol──▶ stock server        ✓ walks
day 30   our client ──authentic protocol──▶ patched, no spells  ✓ still walks
day 90   our client ──────our protocol────▶ narrowed server     ✓ arrived
```

The protocol is thrown away in the end. It is thrown away *from a position of
knowing exactly what it was doing*, which is the only position from which
throwing something away is safe.

The client also gets to be radically incomplete. It needs enough of the
protocol to log in, enumerate characters, enter a world, move, click a thing,
receive other players' movement, and read its own inventory. That is a few
dozen message types out of roughly fifteen hundred. Everything about combat,
spellcasting, chat channels, guilds, auctions, mail, battlegrounds, and pets is
simply never implemented — and by phase 5 it is being deleted from the server
too, so the omission stops being an omission and becomes the design.

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

## Maps: keep the format, inherit the toolchain

We do not invent a map format.

The server independently needs, for any map it hosts, a heightfield for ground
level, a collision soup for line of sight and standing, a navigation mesh for
pathfinding, and a table row saying the map exists. All of it is produced by
extraction tools that already ship alongside the server, and the navigation mesh
is built from the first two by a substantial piece of third-party machinery that
we very much do not want to reimplement.

So the existing format stays, and everything downstream of it works unchanged.
Building on a format that already has a toolchain is what leaves us free to
build whatever we want on top of it later, rather than owing a new format its
entire pipeline before anything can move.

Two consequences, and the first is the good one:

**The collision file is a triangle soup, and our renderer wants triangles.** So
both halves read the *same files*. What you see is what you collide with — not
by synchronisation, but because there is only one set of data and no second copy
to drift from. The bug where the wall on screen is not the wall the server
believes in cannot happen, because there is no second wall.

**The first world is free.** Point the extractors at a copy of the retail
client's data and phase 4 has somewhere to stand on day one: real maps, real
collision, real pathfinding, drawn as untextured flat polygons in four colour
schemes. Which is very nearly the thing the vision describes, arriving before
anyone has authored anything.

That reorders the work in a way worth noticing — seeing a world comes *before*
making one. Custom maps, when they come, emit these same formats, and that is a
later question this decision deliberately does not block.
`docs/datapath-the-world-of-shapes.md` carries the detail.

---

## Where the pieces live

```
   notes/vision ─────────────────────────────── the ask
        │
        ▼
   upstream/azerothcore/  ◀── cloned fresh, gitignored, disposable
        ▲
        │  patches/   apply → build → unapply, exact inverse, verified
        │  modules/   the seam upstream already cut; preferred
        │
        ▼
   authserver (port 3724)      worldserver (port 8085)
        │                            │
        │  SRP6 login                │  RC4-encrypted packet stream
        ▼                            ▼
   ┌────────────────────────────────────────┐
   │  src/   our client, in C               │
   │    net/   ─▶ world/ ─▶ draw/           │
   │    SDL2 for the window, OpenGL to draw │
   └────────────────────────────────────────┘
        │
        ▼
   output/   ── written last; where goodbye goes
```

## Related

- `docs/roadmap.md` — six phases, and the open questions each one carries
- `docs/datapath-the-patch-machine.md` — clone, apply, build, revert, audit
- `docs/datapath-the-handshake.md` — SRP6, and proving a password without one
- `docs/datapath-the-world-stream.md` — header encryption, opcodes, update blocks
- `docs/datapath-the-whisp.md` — how a pink star squiggle is made
- `docs/datapath-the-world-of-shapes.md` — terrain, the four schemes, custom maps
- `docs/table-of-contents.md` — every document, indexed
