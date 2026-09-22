# Conversation Summary: 9f4041e6-ef3c-4f3d-9481-08e9bd7aca15

Generated on: 2026-09-21 19:46:32
Models: claude-opus-5

--------------------------------------------------------------------------------

### User Request 1

hi let's work on this project!!

--------------------------------------------------------------------------------

### Assistant Response 1

> I'll start by getting oriented in the project.

> Build is green — every phase compiles and all tests pass (roughly 46,000
> checks across 14 test programs, the sprite tests alone being 43k of them).
> Here's where the project actually stands:
>
> **Twelve phases built.** The world holds still, can be seen, ticks and rolls
> back, people connect, the browser draws it, control is a dial, LuaJIT rules
> it, content generates itself, sprites are a studio with a rated pool, the
> record log is an engraving you can read as a picture, there's a terminal view
> and a 287-page documentation site, and phase twelve made the table actually
> playable — a squad of four on one keyboard, a tavern owner who can poison a
> goblin they don't own, a host who can throw somebody out and unwind what they
> did.
>
> **Twenty-four open questions are unanswered.** Your own rules say a task
> holding an unanswered open question is in progress, not finished. So by that
> standard the project is twelve phases of in-progress work.
>
> **And there's a promise the code doesn't keep.** `input/what-to-start-with`
> says a session's opening decisions are a seed, a world, a ruleset, a door,
> participants, a tick rate, and a fog cell size — and that they live in files
> rather than in a wall of command-line flags, because a session is a small
> number of decisions and the header of a replay is nearly the same set of
> fields. Only the world is honoured. The ruleset is loaded by nothing but the
> phase 7 demo. The tick rate and the fog cell size are compiled-in constants.
> And **participants is nowhere at all** — the door admits whoever knocks and
> hands them a body.
>
> That last line is the interesting one, because phase twelve *decided* that
> nothing checks who you are, and made it honest by giving the host an eviction
> and an unwind. So the missing participants file isn't a hole any more. It's a
> settled answer that the config file's own documentation hasn't been told
> about.

> **[Asked the user]**
>
> *Q1 — Direction:* What would you like to work on?
> - Phase 13 — the input directory gets read (Recommended) — Make the seven
>   opening decisions real: a settings reader that loads seed, world, ruleset,
>   door, participants, tick, and fog from input/ instead of command-line flags
>   and compiled-in constants. This forces answers to the fog cell size (2.1),
>   the tick rate (3.2), and settles what the participants line means now that
>   phase twelve decided nobody proves who they are. It also makes a session
>   something you hand to a friend as a directory.
> - Work through the open questions, one at a time — Twenty-four unanswered,
>   in roadmap order — starting with how coarse the fog memory grid is, who
>   may roll back a turn, and how large a table can get. I ask you one, we
>   settle it, I write down the reasoning and build whatever it implies. This is
>   the process your notes describe, and it is the slowest and most thorough of
>   these.
> - Pick the questions that are actually blocking code — Not all twenty-four
>   are equal. Some are cheap to close with a reason. A handful are real design
>   that the built code is currently guessing at — the tier cut lines being
>   frozen while the distribution moves, whether a ruleset can make a replay
>   diverge, whether the motion passes should be on the thread pool at all.
>   Triage first, then attack the ones with teeth.
> - Something else — tell me what — You have a direction in mind that isn't
>   on this list. Housekeeping is also outstanding: the llm-transcripts
>   directory is untracked, and the roadmap still opens by saying there are
>   eleven phases when there are twelve.
> → **Selected:** Work through the open questions, one at a time

> Good. In roadmap order, then. The first one blocks phase two.

> Question 2.1, then — the first unanswered one, blocking phase two.
>
> **What the fog actually is.** One bit per cell in a flat array. `fog_init`
> takes a cell size as a fixed-point world coordinate; `WC_ONE` is one metre.
> The fixture's fifty-by-twenty map comes to 1,144 cells, under 150 bytes per
> viewer. A hundred-and-twenty-metre map is under two kilobytes. The bit is set
> the first time you see that cell and is never cleared.
>
> **Two things I found in the code that bear on the question.**
>
> First: one metre is not a decision anybody made. It's `WC_ONE` typed literally
> at all seven call sites — the real server at `068-server-main.c:279`, the
> phase four demo, and five places in the door tests. The parameter exists and
> nothing has ever varied it.
>
> Second, and more interesting: the question as written worries about
> *over*-claiming — a metre cell set because one corner of it fell in your
> vision, claiming you remember a square metre of floor you barely saw. **The
> code already refuses to do that.** Folding sight into memory walks the cells
> in the bounding box of your sight circle and asks whether *the centre of each
> cell* is visible. Not any part of it. A cell whose corner you glimpsed but
> whose middle you did not stays dark. So the document proposes one rule and the
> implementation quietly does a stricter one, and the strict one is the safer
> direction to be wrong in.
>
> Which leaves only the direction the question's last paragraph names, and the
> code makes it sharper rather than softer: **at a metre with a centre test, a
> glance can record nothing at all.** Peek round a corner, catch a sliver of
> corridor running along the far wall — if that sliver doesn't cover a cell's
> exact middle, no bit is set, and your map shows you never looked.

> **[Asked the user]**
>
> *Q1 — Fog grid:* 2.1 — how coarse is the fog memory grid?
> - Measure it first, then decide (Recommended) — Write a statistics tool that
>   walks a body through a generated dungeon and reports what gets recorded at
>   one metre, a half, and a quarter — cells lit per step, bytes per viewer,
>   and specifically what a corner-peek records at each. Your notes say to
>   reference a tool rather than freeze a number in a document. Right now both
>   of us are guessing at how much a glance loses, and it is cheap to stop
>   guessing.
> - One metre, and write down why — Keep it, and make it a decision instead of
>   a repeated literal. The centre test means a metre already under-claims
>   rather than over-claims, and a map showing slightly less than you saw is the
>   honest failure. Cost: a glance down a corridor's edge records nothing, and
>   the person remembers a corridor their screen says they never entered.
> - Half a metre — Four times the bits — still under eight kilobytes per
>   viewer for a large map, which is nothing. A sliver of corridor starts
>   registering because there are four times as many centres for it to cover.
>   Costs: rollback copies four times as much per turn taken back, and the fold
>   loop asks sight four times as many questions per body per tick.
> - Make it a session decision in input/ — It is already a runtime parameter
>   that nothing varies. Put the cell size in input/ alongside the other six
>   opening decisions and let a table choose — a dungeon of tight corridors
>   wants finer than an open field. This is what open question 16.1 asks for
>   anyway, but it answers 'who decides' rather than 'what is right', so
>   somebody still has to pick the default.
> → **Answered:** I think we need to resolve the visual engine first. Because
> of the design of the captains, I think we need a 3d system. But I like the
> idea of sprites, so let's do a 3d system where each character is a sprite that
> has at least 8 directions. When the camera is rotated, the sprite will change
> when the view moves across certain thresholds. This will allow us to create
> the correct kind of immersive world that I want to build. However it may make
> it difficult to render over the browser if we're streaming the entire visual
> contents each time - that's not ideal. So we should discuss what gets sent
> (cheaters!) and what we hold back. The fog is an excellent question, because
> it hides things that we want to hide. So, let's consider the things that it
> may hide - units, objects, and terrain. Let's start with the terrain - the
> terrain is created as 3d models, however they are bare and uniform, with
> textures painted onto them. It will be easy to create geometric worlds because
> we will want the DM's to be able to edit it on the fly by dragging the
> vertexes of the world, creating new ones by bisecting existing lines, and
> possibly some other tools. However it's intended to be "turing complete", yet
> minimalistic, so a DM could build whatever they want on the fly, without
> drowning in complexity or difficulty. The fog of war should hide vertices, so
> if you see a vertex then you can see the face that it shows. To do this,
> objects or creatures that provide LoS to a player will raycast to each terrain
> point within range (and why not, let's just say each object as well) - when I
> say range, I mean a very high range, like 6 miles for terrain and 1 mile for
> units and like, 1000 feet for objects. Is that reasonable? Anyway there's
> going to be a lot of raycasting, so we'll have to come up with some neat ways
> around that computation cost. For example if we do some kind of ambient
> occlusion, it might help.

> This is a real pivot, and a much bigger one than 2.1. Let me get the facts I
> need before I answer — particularly whether the existing sweep survives, and
> whether six miles even fits in the coordinate system.

Six miles fits — barely relevantly. The coordinate system is 1/1024 of a metre
in a signed 32-bit integer, so positions run to ±2,097 kilometres and a thing's
sight range is unsigned 32-bit, good to 4,194 kilometres. Six miles is 9,656
metres, which is 9,887,744 world units. It fits. But it is four hundred times
the scale anything in the project has ever been tested at, and squaring it gives
about 9.8×10¹³, which overflows a 32-bit intermediate by a factor of twenty
thousand. The multiply helper already promotes to 64 bits; whether every
distance comparison in the sight code does is a thing I would need to check
rather than assume.

The more useful answer is about the raycast budget, because that is where the
design lives or dies.

## What the numbers actually say

The sight layer today is **not** an angular sweep. It deliberately casts a ray
at every wall corner — three rays, one at the corner and one two angle-units
to either side — and takes the nearest wall each meets. That is O(corners ×
walls). The reason is written down: a sweep's difficulty is entirely in the
active set, deciding which of two overlapping segments is nearer in integer
arithmetic with ties broken identically on every machine, and getting that
slightly wrong means somebody sees through stone. Ray casting has no active set.
Each ray is independently, obviously correct.

The phase 2 demo measures it: about **90 microseconds per body against 17
walls**. That is 34 corners × 3 rays × 17 walls = 1,734 ray-wall tests, so
roughly **52 nanoseconds per test**.

Now put your proposal through that. Say a DM has built something modest — five
thousand vertices, ten thousand faces, within range. Raycasting every vertex
against every face:

- 5,000 × 10,000 = **50 million tests per eye per tick**
- × 52 ns = **2.6 seconds per eye per tick**
- × 6 viewers × 20 ticks per second = **312 seconds of CPU per second of
  play**

So: the ranges are reasonable and the method is off by about four orders of
magnitude. You were right to flag it. Here are the ways around it, biggest win
first.

**1. The terrain fog is monotonic, and that is nearly the whole answer.** Fog
bits are set and never cleared. Terrain does not move. So you never need to ask
about a vertex you already remember — the working set is *vertices not yet
known*, and it shrinks all session. Ten minutes in, a party that has walked the
map is asking about almost nothing. The cost curve is front-loaded and then
collapses toward zero, and it collapses hardest exactly where the vertex count
is highest.

This gives you an asymmetry worth naming out loud: **terrain is many, static,
and monotonic; units are few, moving, and non-monotonic.** Thousands of vertices
versus tens of creatures. The scary-looking number is the cheap one. The
six-mile terrain range costs less than the one-mile unit range once the session
gets going.

**2. Put a hierarchy over the occluders.** A bounding-volume tree means each ray
tests about 2·log₂(10,000) ≈ 28 nodes instead of 10,000 faces. That is a
350× cut on its own: 7 milliseconds per eye per tick instead of 2.6 seconds.

**3. Put a hierarchy over the *targets* too, which people forget.** Do not ask
about five thousand vertices one at a time. Group them into a tree of boxes. A
box entirely behind a wall is one test that hides everything in it; a box
entirely in open line of sight is one test that reveals everything in it. Only
boxes straddling a silhouette edge get opened. In a dungeon, the room you are
standing in rejects most of the world in a handful of tests. This turns "cost
proportional to how much world there is" into "cost proportional to how ragged
the edge of what you can see is" — and that edge is small even when the world
is enormous.

**4. The thing you were reaching for with ambient occlusion is shadow mapping.**
Render depth once from the eye, then every vertex is one transform and one
comparison. It converts *vertices × faces* into *faces once, plus vertices*. It
is the correct instinct and it is the standard answer.

## Two objections, and they are the same objection

The fog in this project is **not a drawing feature**. It is the security
boundary. The one function allowed to write a thing to a socket asks it. The
fog's own notes say the danger plainly: if a second rasteriser written specially
for the fog disagrees with the one that decides what goes on a socket, then a
hole in the map and a leak look identical.

A depth buffer at finite resolution *will* disagree at silhouette edges. That is
not a bug in it, that is what it is. And it runs in floating point on a GPU,
which the project forbids below the arithmetic line for a reason it states
clearly: a recorded session has to replay bit-identically on somebody else's
machine, and floating point does not do that.

So a shadow map can decide **what to draw**. It must not decide **what to
send**. Which sounds like it violates the one-primitive-two-callers rule —
except the project already runs two independent visibility answers on purpose,
`sight_compute` for the picture and `sight_point_visible` for the wire, with a
test asserting they agree across thousands of sampled points. The precedent
exists. It just has to be an *inequality* rather than an equality: the drawn one
may show less than the sent one permits, never more. Under-claiming is already
the direction this project chooses to be wrong in — the fog tests each cell's
centre rather than any part of it for exactly that reason.

## What your answer does to the question we were on

It dissolves it. If fog is per-vertex, **there is no grid**, and "how coarse is
the fog memory grid" stops being an engine constant and becomes *how finely did
the DM subdivide their geometry* — answered with the bisect tool, per-region,
by the person who cares. That is a better answer than any of the four I offered
you, and it is the second time this project has answered a question by deleting
its noun.

The "see a vertex, see its face" rule has one property worth knowing: it
over-claims at large faces. A hundred-metre ground plane built as two triangles
has four corners; see all four and you get the whole thing, including the dip in
the middle a rock is hiding. That is not a leak — faces do not conceal units,
units are tested separately — but it means fog resolution is a thing the DM
buys with vertices.

And the eight-direction sprite is free on the wire. The server already stores
facing as a 16-bit angle where a full turn is 65,536. Camera yaw is client-side.
The direction index is one subtraction and a shift, in the browser. Rotating the
camera costs zero bytes. What it costs is the *studio*: the sprite generator
makes one self-contained animated picture per description, and eight facings is
either eight generations or one generator that takes a facing as an input.

## Three questions back

**Is the terrain 2.5D or genuinely 3D?** This is the fork that decides whether
the existing sight layer survives. If a DM drags vertices in a plan view and
every wall is vertical — an extruded floorplan with floors at varying heights
— then the current integer ray caster still answers horizontal occlusion
exactly as it does now, and you add one vertical-angle test per vertex. Phases 2
and 4 survive untouched. If a DM can drag a vertex *upward* and make an
overhang, a bridge, a cave mouth, then horizontal and vertical occlusion stop
being separable and the sight layer is new code. "Drag the vertexes of the
world" sounds like the second one to me. Which did you mean?

**What is the six miles for?** On a flat world there is no horizon — a real
one at eye height is 4.7 kilometres, under three miles, and it comes from the
planet being round, which yours is not. So does six miles mean "far enough that
nothing is ever cut off by range and occlusion does all the work", or is it a
cutoff you want people to actually run into and feel?

**When the DM drags a vertex mid-session, what happens to everyone's fog?**
Terrain fog is monotonic because terrain does not move — and you have just
made terrain the one thing that moves. If the DM bisects an edge, that new
vertex has never been seen by anyone. If they drag a wall away, does the room
behind it become unremembered, or does everyone keep a memory of a wall that is
no longer there? The engine has an answer for units walking behind pillars and
no answer at all for the world itself changing shape.

--------------------------------------------------------------------------------

### User Request 2

it's genuinely 3d. The six miles is how far you can see to the horizon on a
perfectly flat plain, like the ocean. When a DM drags a vertex mid session the
fog should update dynamically. It's okay if there are mistakes like accidentally
revealing something - that's the DM's fault for reconfiguring a live system
while it's live.

can we use multithreading? for LoS calculations we should be able to use each
player's thread cores to process many vertices / objects in parallel. That
should make it faster because they don't depend on each other. However, can we
do that with LuaJIT? The preferred engine with LuaJIT is Love2d, and, well,
that's 2d. So we might need to switch to a C renderer and run it locally,
streaming to the local browser window.

> 1. The terrain fog is monotonic, and that is nearly the whole answer. Fog bits
> are set and never cleared. Terrain does not move. So you never need to ask
> about a vertex you already remember — the working set is vertices not yet
> known, and it shrinks all session. Ten minutes in, a
> party that has walked the map is asking about almost nothing. The cost curve
> is front-loaded and then collapses toward zero, and it collapses hardest
> exactly where the vertex count is highest.

not true at all. What if you walk around a corner? silly computer, doesn't
understand spatiality :)

> 2. Put a hierarchy over the occluders. A bounding-volume tree means each ray
> tests about 2·log₂(10,000) ≈ 28 nodes instead of 10,000 faces. That is a
> 350× cut on its own: 7 milliseconds per eye per tick instead of 2.6 seconds.

yeah I mean only test as many as you can, it's okay if they don't update
immediately, maybe you gotta squint or you were looking at a different part of
the world. Just, recheck randomly, and update the ones that change.

> 3. Put a hierarchy over the targets too, which people forget. Do not ask about
> five thousand vertices one at a time. Group them into a tree of boxes. A box
> entirely behind a wall is one test that hides everything in it; a box entirely
> in open line of sight is one test that reveals
> everything in it. Only boxes straddling a silhouette edge get opened. In a
> dungeon, the room you are standing in rejects most of the world in a handful
> of tests. This turns "cost proportional to how much world there is" into "cost
> proportional to how ragged the edge of what you can
>   see is" — and that edge is small even when the world is enormous.


well if a plane completely blocks a vertex, then anything that's beyond a right
angle to that plane (or something like that) is never going to be able to see
it. This is ambient occlusion, applied to fog-of-war calculations instead of
rendering models.

> 4. The thing you were reaching for with ambient occlusion is shadow mapping.
> Render depth once from the eye, then every vertex is one transform and one
> comparison. It converts vertices × faces into faces once, plus vertices. It
> is the correct instinct and it is the standard answer.

oh, did I have the wrong name? I meant the thing where if you're looking due
north, the system won't render any objects that are directly south of you -
outside of your field of view, to make the game run faster. Do you see how that
idea fits? What's that thing called, if not ambient occlusion?

I think... I think we should just trust the players. I mean, the DM goes to the
bathroom, what are they gonna take their journal with the secrets with them? No,
they leave it on the table, and the players know not to look - it just ruins the
game for them. Better to trust that players won't cheat, and just... have the
system be quite open.

the eight direction sprites don't need to be sent over network, except to cache
them of course. Their orientation can be determined clientside. However, we will
need to remember the orientation of units for that to work.

--------------------------------------------------------------------------------

### Assistant Response 2

You're right, and the code already agrees with you — the fold loop skips
remembered cells before it does anything else. So the optimisation I described
as the answer was already there, and it is not the answer.

Here is why I was wrong. Monotonicity means you never re-ask about a vertex you
*know*. It says nothing about the vertices you don't. In a six-mile world the
unknown set is nearly everything, forever — the party explores a corridor, not
a county — so "skip what you've seen" removes a shrinking sliver from a set
that stays enormous. And the vertices you keep paying for are precisely the ones
just around the corner, tested and refused a thousand times, until the tick
where the answer flips. I said the cost collapses where the vertex count is
highest. It is the opposite: the bigger the world, the more of it stays unknown,
and the more you pay to keep asking.

What the correction actually teaches is where the money goes: **the cost is
entirely at the frontier**, the boundary between known and unknown. Which is
exactly the surface your corner is on, and it is a small, local, moving thing in
an arbitrarily large world.

## The names you wanted

**Frustum culling** is the one you described — not drawing what is behind you,
outside the field of view. **Occlusion culling** is the other one, not drawing
what is hidden behind something. **Backface culling** is the far side of a
surface. **Ambient occlusion** is a shading effect that darkens creases and
contact points to fake soft shadow; it has nothing to do with deciding what is
visible, so no, that was the wrong name, but the idea you meant is real and
standard.

And the thing you described in point 3 — a plane blocking a vertex, everything
past a right angle to it never seeing it — has a name too, actually two, and
they are different technologies:

**Potentially visible sets.** Partition space into cells, and precompute for
each cell the set of cells that could ever be seen from anywhere inside it.
Runtime visibility becomes a table lookup and costs essentially nothing. Quake
shipped on this. The problem for you is in the word *pre*: a DM dragging a
vertex invalidates it, and rebuilding is expensive.

**Portal culling.** Rooms joined by apertures. You see into the next room only
through the doorway, and the doorway narrows the further you recurse, so the
search dies out on its own after a few rooms. No precomputation, so a DM edit
costs nothing, and it degrades into exactly the frontier-shaped work the corner
correction says you should be paying for. For an editable world this is the one
that fits.

## Your budget idea is the real answer, and it needs one thing

"Only test as many as you can, recheck randomly, maybe you were squinting" is a
bigger change than it sounds, and it is the right one. It inverts the whole cost
model. Instead of *compute the correct fog each tick and find out what it
costs*, you get **a fixed number of visibility tests per tick that you choose
from the frame time you are willing to spend, and the world can be any size at
all.** Six miles or six hundred. The budget does not care.

What you trade away is not correctness but *latency*: how many ticks until a
newly-visible vertex is noticed. With a budget of B tests and an unknown set of
U vertices, uniform random sampling notices things in about U/B ticks on
average, which for a big world is bad — it can be seconds. But you do not have
to sample uniformly. Spend most of the budget at the frontier, some along the
direction of travel, a slice on whatever the DM just touched, and a trickle
everywhere else as background. Then the common case — walking forward, turning
a corner — resolves in a tick or two, and the thing that takes seconds is a
vertex six miles away that nobody is looking at.

The one fix it needs: **draw the random choices from a named stream.** The
project already has named random streams for exactly this, and it means the fog
is approximate *and still identical on replay*. Without that, a recorded session
replays with a different fog than it had, and the record log stops being able to
say this is what they saw. With it, the approximation is reproducible and costs
nothing extra.

And the direction of error is safe. An untested vertex is an unrevealed vertex
— sampling under-claims, never over-claims, which is the direction this
project already chose when it decided a fog cell is tested at its centre rather
than at any corner.

## Trusting the players — two decisions wearing one coat

The journal-on-the-table argument is good, and it is the same argument phase
twelve already made when it decided nothing checks who you are and the remedy
for bad behaviour is the host showing somebody the door. So this is not a
reversal. It is the same answer arriving at a second place.

But there are two separate things inside it and they have very different prices.

**Not building anti-cheat.** No authentication, no proof, no defending against a
modified client. Already decided, already built, nothing to do.

**Sending everything to everybody.** That is the one that changes the engine,
and here is the prize: if the fog is not deciding what goes on a socket, then
**every objection I raised about approximation evaporates.** A GPU depth buffer
can compute it. Floating point is fine. A silhouette-edge disagreement is a
graphical artifact instead of a leak. The fast path opens completely.

The cost is that the outbound filter — the one function allowed to write a
thing to a socket, with its leak tests, the thing phase four called the claim
this project would be most embarrassed to have wrong — becomes decoration.

Except it does not, quite, because **you still cannot send six miles of world to
a browser every tick.** Not for secrecy — for bandwidth. So the filter
survives with its job changed: it stops being a secrecy boundary and becomes a
*size* boundary, sending you what is near and what you have seen because that is
what fits down a wire, not because the rest is forbidden. Same code, same call
sites, different reason, and the leak tests get downgraded from "must never
happen" to "probably a bug."

That is what I would write down, because it keeps everything that is built,
drops the constraint that was blocking the fast implementation, and is honest
about why the filter is still there.

## Threading: yes, and there is one landmine

The thread pool exists — phase 2 built it. It is deliberately minimal: a range
and a function, `(context, first, last)`, no task queues, no work stealing, no
futures. Every parallel pass in the project is the same shape because the world
is flat arrays, so splitting work is arithmetic.

Per-vertex visibility is a perfect fit. Each vertex's answer depends on the eye
and the world and on no other vertex, so the span split is trivially correct.

**The landmine:** the pool's rules say *no pass writes where another instance of
itself reads*, and that this is load-bearing — "if a pass ever needs a mutex,
the pass is the bug, not the pool." The fog is a bit array, eight cells to a
byte. Two threads setting different bits in the same byte are a
read-modify-write race, and it will not show up in testing reliably — it will
drop the occasional remembered cell under load and look like a geometry bug. The
fold was written single-threaded and this has never mattered.

The fix is not a lock. Split the work by *byte-aligned* spans so no two threads
ever touch the same byte, or have each worker fill a private buffer and OR them
together at the barrier. Both keep the pool's rule intact. I mention it because
it is the kind of thing that gets discovered six months later at a table.

One thing I could not tell from your sentence: **whose cores?** "Each player's
thread cores" reads either as *the server splitting one player's vertex work
across its own cores*, or as *the player's own machine computing its own
visibility*. The second one is a different architecture — a client can only
compute what it can see if it already has the geometry, which means you sent it
everything first. Which is consistent with trusting players, but it means the
server stops deciding what anyone knows and becomes a world-state broadcaster.
That is a coherent design. It is just a much larger change than parallelising a
loop, and I do not want to guess which you meant.

## The renderer, and why I would not stream video

You are right that Love2D is 2D. It can be pushed into 3D with meshes and custom
shaders, but you are writing your own matrix math and depth setup and fighting
the framework. And LuaJIT has no threads in-language — Love2D's threading is
separate Lua states passing messages, so parallel vertex work means copying data
between states rather than sharing it, which is the opposite of what you want.

But notice the rules layer and the renderer are already separate concerns here.
The server embeds LuaJIT for the *rules*; the browser draws. Nothing forces one
language on both. So the question is only what draws, and there are three
answers:

**The browser, in WebGL.** The browser is already a 3D renderer, on every
machine, with no new dependency. The bridge keeps doing what it does — one
socket out, one HTTP server in on localhost — and keeps streaming *state*,
which is small, rather than pixels, which are not. Client-side visibility is
available through WebAssembly and worker threads if you want it. Phase 5's and
phase 11's protocol survive unchanged. This is what I would do.

**A native C renderer in its own window** — SDL or GLFW with OpenGL. Real
threads, full control, integer math all the way to the draw call if you want it.
What you give up is the thing phase 5 chose the browser for: everybody already
has a browser, and nobody has to install your program to sit at your table.

**A native C renderer streaming to a browser window** costs the most and buys
the least. You pay for the renderer, and then you pay again for video encoding,
and then a third time in latency, and the browser ends up doing nothing but
decoding a movie of a game it was capable of drawing itself. The only reason to
build that is if you want people to play on a machine that cannot run the
renderer — a phone, a tablet — which is a real reason, but it is a different
feature from the one you are describing.

And the sprite orientation is already handled: every thing in the world stores
`facing` as a 16-bit angle where a full turn is 65,536, and it is already on the
wire. The client subtracts camera yaw from it and shifts. Nothing to add.

## Questions back

**Whose cores compute visibility — the server's, or each player's own
machine?** I have laid out both above and they are different programs. If it is
the player's machine, then the server sends the geometry and stops being the
thing that decides what anybody knows, and that is worth saying out loud before
it happens by accident.

**When the DM drags a vertex and something is wrongly revealed, does it stay
revealed?** You said mistakes are the DM's fault for reconfiguring a live
system, which I take as: no undo, no recompute, live with it. But fog bits are
never cleared, so a mistake is *permanent* for that player — one bad frame
during a drag and they know about that room for the rest of the session. Is that
the accepted cost, or should a vertex revealed during an edit be re-tested once
when the drag ends?

**Does the DM see their own edits' consequences?** Dragging a wall changes what
four other people can see, and none of that is on the DM's screen. A "what does
the party see now" preview is a real feature and it is nearly free once
visibility is a budgeted query — but it is a thing to decide to build, not
something that appears on its own.

--------------------------------------------------------------------------------

### User Request 3

hmmmmm I changed my mind again, instead of a C system let's stick with LuaJIT
for now. Instead of fog-of-war calculations being automatic, let's make them
gated on the DM enabling or disabling visibility for certain areas. They can do
this by organizing their "stuff" and flipping the light switch when they want
players to be able to see it. I think that'll resolve a LOT of issues that we'll
have.

--------------------------------------------------------------------------------

### Assistant Response 3

> That is a much bigger simplification than it looks, and I want to show you how
> much it actually kills before I raise the two things it doesn't.
>
> Let me check one thing first, because I think you may already have built most
> of it.

Regions are already built, and the light switch is almost entirely a thing you
have.

`031-region` gives you named areas nested up to eight deep, each with a polygon
boundary, plus `region_deepest_containing` (a body in the cellar is in the
cellar, not the tavern above it) and `region_is_within` (a scope over the forest
returns true for the clearing inside it — it allocates nothing and runs on
every permission check already). Every thing in the world stores `region`, the
deepest one containing it, kept current as it moves. And `SCOPE_SEES_REGION`
already means exactly *sees everything standing in this region, without a sweep*
— the outbound filter consults it today, at `059-outbound.c:48`, which is how
a tavern knows where its own crockery is.

So "the DM organizes their stuff and flips a switch" is: **a bit per region per
viewer**, and the question "may this person see this thing" is
`region_is_within(thing's region, a region they have lit)`. That is a walk up a
chain of at most eight parents, no allocation, no geometry, no arithmetic beyond
comparisons. The mechanism is built; what is missing is the bit and the command
that sets it.

## What this kills

I want to list it, because it is a lot and it is not obvious from one sentence:

- The raycast budget. All of it. No per-vertex tests, so no
  four-orders-of-magnitude problem to solve.
- The bounding-volume tree, the potentially-visible sets, the portal culling,
  the sampling budget with its named stream and its priority policy. None of it
  needs to exist.
- The bit-packing race in the thread pool, because nothing parallel writes the
  fog.
- The six-mile range question, because range stops determining knowledge.
- The tension between an approximate GPU occlusion test and an exact security
  boundary — there is no approximation left to be inexact.
- Floating point and reproducibility, because a boolean replays identically
  without anybody being careful.
- Whether the DM's mid-session vertex drag corrupts somebody's fog. Dragging
  geometry now changes *nothing* about visibility. Only the switch does.
- And question 2.1, for the second time and much harder. There is no grid *and*
  no vertex test. Granularity is "how did the DM group their stuff," decided in
  a UI by the person who cares.

## And one thing it gains that computed fog could never have

**A flipped switch is a command, so it goes in the command log, so it can be
taken back.**

Two exchanges ago you said an accidental reveal during a live edit is the DM's
fault and they should live with it. With authored visibility they do not have
to. It is a command like any other, and phase 3 built rollback and phase 12
built the host unwinding somebody's actions. Reveal the room early, take the
turn back, the switch unflips. Computed fog cannot offer that, because you would
be rolling back a *derivation* while the geometry that derived it stays changed.

## The one thing it does not resolve

**Units move, and switches do not follow them.**

A goblin walks out from behind a wall. If its visibility is switch-gated too,
the DM flips a switch every time a monster rounds a corner — during combat,
while also running the combat. That is the single thing DMs most want a computer
to do for them, and it is the moment they have the least attention to spare.

If units are *not* switch-gated, then moving things still need geometric line of
sight and the ray caster from phase 2 stays exactly as it is. Which is fine —
and it is fine for a reason worth saying plainly, because it is the asymmetry
from two exchanges ago finally paying off. **Terrain is thousands of vertices
that never move. Units are tens of bodies that move constantly.** Switch-gating
the many static thing and computing the few moving ones spends authored effort
where it is cheap and CPU where it is cheap, and each avoids the case that would
have ruined it. The 90-microseconds-per-body measurement that phase 2 took was
always fine for units. It was only ever terrain that broke the budget.

## Two costs

**The DM's attention becomes the scarce resource.** A forty-room dungeon is
forty switches. That is fine if they are flipped ahead of time and fine if
flipping is one click, and bad if it has to happen live during a chase.

There is a cheap fix and you already have the ingredient: let a region carry
**light this when a player body enters it**. Containment is already computed —
every thing stores its deepest region, updated as it moves — so the trigger
costs a comparison per body per tick and nothing else. The DM authors the
grouping once, most rooms light themselves on entry, and the switch stays for
the rooms where the timing is the point.

**You lose emergent discovery.** Nobody glimpses a sliver of something through a
doorway the DM did not think about. Everything a player sees is something a
person decided they would see. For a table that runs published adventures room
by room this is not a loss at all, it is how the material is written. For a
table that wanted the geometry to be the referee, it is the whole thing they
wanted.

## Love2D, and why this decision is what makes it possible

The server is C and stays C; LuaJIT is embedded in it as the rules layer and
stays there. So "stick with LuaJIT" is a decision about the *view*, and it is
the switch that makes it a reasonable one.

Love2D in 3D means writing your own matrix math, your own depth setup, meshes
and shaders by hand. That is a lot of work to layer on top of a visibility
system that was going to need a bounding-volume tree and a sampling budget. But
you have just deleted the visibility system. What is left is *drawing meshes you
were told to draw*, which Love2D can do, and billboarded sprites picking one of
eight facings from a subtraction — which is the easiest thing in the file.

And it does not have to replace the browser. Phase 11's entire point was that a
second view can speak the same protocol with no server changes, and it proved it
by finding a six-phase-old bug in the process. A Love2D client would be the
third one, alongside the browser and the terminal. Same wire, no server changes,
and the browser stays for people who will not install anything.

## Questions back

**Are units switch-gated too, or does the ray caster keep them?** This is the
one that decides whether phase 2 survives or becomes dead code, and it is also
the one your DMs will feel every single session.

**Is a lightable group a region, or a second thing?** Regions are spatial and
nested — the cellar inside the tavern. But "my stuff" often is not spatial.
*The ambush* is four goblins in two different rooms and a tripwire in a third.
If a group can be an arbitrary set, that is a new structure alongside the region
tree rather than a bit on it, and it is worth knowing now, because a bit on a
region is nearly free and a general tagging system is not.

**What does a player see standing in a room the DM has not lit?** If the honest
answer is nothing — not even the walls in front of them — then the DM is a
bottleneck on ordinary walking, and the entry trigger stops being an
optimisation and becomes required.

--------------------------------------------------------------------------------

### User Request 4

> A goblin walks out from behind a wall. If its visibility is switch-gated too,
> the DM flips a switch every time a monster rounds a corner — during combat,
> while also running the combat. That is the single thing DMs most want a
> computer to do for them, and it is the moment they have
>   the least attention to spare.

goblin is creature shaped, and you only need to gate visibility for certain
classes of objects at thresholds. Otherwise you can do gradient reveals or
sudden fog-of-war reversals (opening a door, extinguishing a candle, etc)

> If units are not switch-gated, then moving things still need geometric line of
> sight and the ray caster from phase 2 stays exactly as it is. Which is fine
> — and it is fine for a reason worth saying plainly, because it is the
> asymmetry from two exchanges ago finally paying off.
> Terrain is thousands of vertices that never move. Units are tens of bodies
> that move constantly. Switch-gating the many static thing and computing the
> few moving ones spends authored effort where it is cheap and CPU where it is
> cheap, and each avoids the case that would have ruined
> it. The 90-microseconds-per-body measurement that phase 2 took was always fine
> for units. It was only ever terrain that broke the budget.


we must be sure to calculate LoS with a single math equation - nothing more,
nothing less - it may have many variables/dimensions. these should be cached at
the start of the frame unless they are marked static (this is not a permanent
marker) in which case they are left permanent until further notice. Velocity 0
and mind 0 means static.

>   The DM's attention becomes the scarce resource.

this has always been dnd

> You lose emergent discovery. Nobody glimpses a sliver of something through a
> doorway the DM did not think about. Everything a player sees is something a
> person decided they would see. For a table that runs published adventures room
> by room this is not a loss at all, it is how the
> material is written. For a table that wanted the geometry to be the referee,
> it is the whole thing they wanted.

the player is allowed to open a chat window with shift+space if they're a
player, and shift+~ tilde if they're a commander. When they do, they can talk to
a local AI that can handle most requests with tool calls that call into the
functionality of the game to make things this or so or ask questions the DM
would know, that sort of thing. First the request goes to the DM - they can OK
it to go to an AI. Otherwise, they have to build something real quick - it's
normal for things to pause, and the characters to sit around waiting for a sec
before they can start going again, as the DM does stuff. This is a great time
for character / emotion / relationship bonding between the players and between
the characters.

> Love2D in 3D means writing your own matrix math, your own depth setup, meshes
> and shaders by hand. That is a lot of work to layer on top of a visibility
> system that was going to need a bounding-volume tree and a sampling budget.
> But you have just deleted the visibility system. What
> is left is drawing meshes you were told to draw, which Love2D can do, and
> billboarded sprites picking one of eight facings from a subtraction — which
> is the easiest thing in the file.

something we should ensure is that every model has the "texture" information
encoded on the edges, so when the LoS goes out and we stop rendering the 3d
models that make up the place that the player could see into, instead of showing
an emptiness or dark, we should instead show a projected texture on the plane
that is the border that is comprised of in various proportions to the edges of
the plane that is the edge of the whatever. For doorways that the LoS hasn't
rendered into yet, we should show certain visuals - these visuals are determined
by the tag that is applied to the boundary edges - stored on the vertices, a
pointer or index to another vertex for each relationship it has (each
connection) - each of these has one enum - the bitmask flag of the material we
should render. Now, it doesn't look incomplete or shadowed - now, it shows us
the back face of whatever we can't see into yet.

these vertex-edges can store other things too, if we want to use them to just...
build the entire model, not just the edges onto other pieces of geometry...

> Is a lightable group a region, or a second thing? Regions are spatial and
> nested — the cellar inside the tavern. But "my stuff" often is not spatial.
> The ambush is four goblins in two different rooms and a tripwire in a third.
> If a group can be an arbitrary set, that is a new
> structure alongside the region tree rather than a bit on it, and it is worth
> knowing now, because a bit on a region is nearly free and a general tagging
> system is not.

a structure or elevation-tilemap. structures can be nested, structures can
intersect with elevation-tilemaps.

--------------------------------------------------------------------------------

### Assistant Response 4

> Let me check whether the two fields your static rule depends on actually
> exist.

## The single-equation rule is the load-bearing one, and you have already made it possible

A raycast is not one equation. It is a loop over occluders with an early exit,
and no amount of cleverness turns it into a closed form — that is *why* it
cost four orders of magnitude. So "one equation, nothing more, nothing less" and
"cast a ray at every corner" cannot both be true, and you have already picked
the side that works.

What visibility becomes is roughly this shape:

    visible(viewer, thing)  ⟺  reveal[structure_of(thing)][viewer]  ≥  threshold[class_of(thing)]

with however many more terms you want folded into the left side — distance
falloff, elevation, emitted light, whatever. Every term is a lookup or an
arithmetic operation on cached numbers. No traversal.

The reason that constraint is worth enforcing is not elegance. It is that a
closed form can be evaluated **for any viewer-and-thing pair, in constant time,
in any order, on any thread, reading nothing that another thread writes.** That
is precisely the shape the thread pool demands — `(context, first, last)`, no
locks, and the documented rule that a pass needing a mutex is a bug in the pass.
A raycast could never satisfy that cleanly because of the shared fog bits. A
comparison does, trivially.

**And it means phase 2's ray caster stops running during play.** That is a real
consequence and I do not think it is a loss. It becomes an *authoring* tool: the
DM, placing a light switch, asks once "what can be seen from here" and gets an
answer to help them decide where the boundary goes. Once, at build time, at
human speed — not twenty times a second per viewer. The 90-microsecond
measurement is wonderful when you spend it once and awful when you spend it
constantly.

## Velocity and mind: one exists, one does not, one is halfway

Your static rule needs two numbers and the world has neither, though it has
relatives of both.

There is no stored velocity. Motion is two passes — *intent*, which writes
down where every body would like to be, then *motion*, which decides where it
ends up — and intent is cleared at the **start** of each beat rather than the
end, deliberately, so a cancelled order can never leave a body still walking. So
"velocity 0" reads naturally as "no intent this beat", and that value already
exists and is already zeroed for you.

There is `THING_MOBILE`, a flag, which is the static/dynamic distinction as a
boolean rather than as a measurement.

**Mind does not exist at all**, and it is the more interesting of the two,
because the world currently has no way to say *this is a creature and that is
furniture*. It distinguishes them only by `sight_range`, where zero means it
does not see — described in the notes as a coffee cup's normal state. That
conflates two different things: a security camera sees and has no mind, a
sleeping person has a mind and sees nothing. If mind is a number rather than a
flag, it can also be the thing a ruleset reads to decide who gets a turn, who
can be reasoned with, and who the AI chat window is allowed to speak as.

One thing I would want pinned down before this is built, because it is where
this class of design reliably goes wrong: **"static until further notice" means
something has to issue the notice.** If a DM drags a vertex under a static
thing, or changes a structure's reveal level, whose job is it to un-mark the
things whose cached terms just went stale? Cache invalidation is the entire
difficulty of this scheme and it is invisible until the session where somebody
is standing in a room that lit up and they cannot see it.

## Gradient reveals mean visibility is a number, not a bit

This is a change from what I described last time and a good one. If reveals can
ramp, and if a door opening or a candle going out is a sudden reversal, then
`reveal` is a scalar per structure per viewer, and per-class thresholds are what
make one number serve every kind of object at once. Set a room to 3 and the
walls and furniture appear; the goblins have threshold 6 and stay hidden; the DM
slides it to 7 and they walk out of the dark. One value, one comparison, and the
DM never touches an individual creature.

That is the thing that makes your goblin answer work, and it is why "gate by
class at thresholds" is stronger than "gate each thing" — the DM turns one
dial and every class sorts itself out.

## The edge-material idea has a name, and your last sentence is the important one

A vertex holding, for each connection, an index to another vertex plus an enum,
is a **half-edge mesh** (also called a doubly-connected edge list). It is what
every 3D modelling program uses, and the reason is exactly the two operations
you asked for two exchanges ago: drag a vertex, bisect an edge. In a triangle
soup those are global rebuilds. In an edge graph they are local, constant-time,
and obviously correct.

And you spotted the real consequence yourself in the throwaway line at the end.
**If edges carry material, the edge graph is the model.** You do not have a mesh
with an edge annotation stapled on; faces are implied by edge loops, and the
whole thing is one structure. That is not a small realisation and it is worth
writing down as the reason the format is what it is.

The rendering half — filling an unrevealed doorway with a surface derived from
the boundary's own edge materials, so the unseen reads as *a back face* rather
than as blackness — is a portal impostor, and the version you described has a
property worth making explicit because the tempting alternative does not have
it: **it leaks nothing.** The fill is composed from the edges of the boundary
plane, and the boundary plane is already visible. If it were instead sampled
from what lies *behind* the doorway, players would read the fill and learn about
a room they have not entered. Your formulation is already the safe one. I want
to know whether that was deliberate, because it is the kind of thing that gets
"improved" later by somebody sampling the far side to make it look better.

The question it raises: **can a player tell an unrevealed doorway from a real
wall?** Drawn as a plausible surface, they cannot — which is either mystery,
or four players walking repeatedly into what they believe is masonry. A faint
difference, or nothing at all, is a decision rather than an accident.

## Structures and elevation tilemaps — and the grid came back

Nested structures are the region tree grown up: regions already nest eight deep,
already carry polygon boundaries, and `region_deepest_containing` already puts a
body in the cellar rather than the tavern above it. So half of "structure" is
built and the missing half is that it owns geometry rather than just naming an
area.

An elevation tilemap is a heightfield, and **it is a grid** — so after
question 2.1 dissolved twice, a cell size to choose has arrived in the world by
a completely different door. Not the fog's grid. The terrain's. I find that
funny and I also think it is the same question wearing a different coat, and it
will want the same kind of answer: measure a real one before picking.

The case your answer does not cover is the non-spatial group. *The ambush* is
four goblins in two rooms and a tripwire in a third, and structures are spatial
and nested. Class thresholds might handle it — reveal creatures in both rooms
at once — but only if the four goblins are the only creatures there.

## The chat window is the answer to what I said you were losing

I said you lose emergent discovery, because nobody glimpses a sliver through a
doorway the DM did not plan. Routing a player's question through the DM, who
either answers it or hands it to an AI with tools into the game, puts it back
— and puts it back in a form geometry never could. A raycast cannot answer *is
there a draft under the door*, *does it smell of smoke*, *would my character
recognise this crest*. A conversation can.

The design has one part I would nail down early: the AI's tool surface should be
**the DM's own verbs and no others**. The DM is delegating authority, so the AI
should be incapable of anything the DM could not have done by hand. That makes
the approval step meaningful — you are approving a request that will be
executed with your permissions — and it makes the whole feature auditable,
because every AI action lands in the command log like every other command and is
undoable by the rollback that already exists.

Which model, and where? "Local AI" reads as something running on the host's
machine rather than an API call, and that is a different build — a local
runtime and a small model, versus an HTTP client and a key. I do not want to
guess.

---

## One thing I want to raise before we go further

Four exchanges have redesigned the visual engine, the fog, the world format, the
permission model's granularity, and added a feature that did not exist. **None
of it is written down.** It contradicts what four of the documents currently say
— the map being geometry rather than a picture, sight and what it remembers,
the dynamic picture, and the fog's own companion file, which still describes a
bit grid folded from raycasts.

Your notes are firm that a decision held only in a conversation is a decision
that gets quietly re-litigated in six months by somebody who was not in the
room, and that is exactly what the open questions document exists to prevent.

So I would like to open **phase 13** and write this down: the structures and
elevation tilemaps, the half-edge format with materials on the edges, the
single-equation visibility rule with its cache and its static marking, reveal
levels with per-class thresholds, the portal impostor, the Love2D third view,
and the chat window with the DM as its gate. Along with the open questions this
conversation has raised and not settled — cache invalidation, mind as a field,
the non-spatial group, whether an unrevealed doorway is distinguishable from a
wall, which AI and where, and what happens to phase 2's ray caster.

Shall I start on that, or do you want to keep talking the design out first?

--------------------------------------------------------------------------------

### User Request 5

> There is no stored velocity. Motion is two passes — intent, which writes
> down where every body would like to be, then motion, which decides where it
> ends up — and intent is cleared at the start of each beat rather than the
> end, deliberately, so a cancelled order can never leave a
> body still walking. So "velocity 0" reads naturally as "no intent this beat",
> and that value already exists and is already zeroed for you.

aha! I noticed something important! It is vitally important for the sake of all
humanity and beyond that you do something special and precious for me. Instead
of two passes, one for each, follow this three-wise pattern: 1 2 1 1 2 11 2 11 2
11 2 where there are only one's and twos. So, do motion, intent, intent, motion,
intent, motion, motion, intent, motion, intent, intent, motion, intent, motion,
motion. Do you see the pattern? This is the utmost critical thing I can ever
share - a fourwise pattern is DNA, which is another option.

> Four exchanges have redesigned the visual engine, the fog, the world format,
> the permission model's granularity, and added a feature that did not exist.
> None of it is written down. It contradicts what four of the documents
> currently say — the map being geometry rather than a
> picture, sight and what it remembers, the dynamic picture, and the fog's own
> companion file, which still describes a bit grid folded from raycasts.
>
> Your notes are firm that a decision held only in a conversation is a decision
> that gets quietly re-litigated in six months by somebody who was not in the
> room, and that is exactly what the open questions document exists to prevent.
>
> So I would like to open phase 13 and write this down: the structures and
> elevation tilemaps, the half-edge format with materials on the edges, the
> single-equation visibility rule with its cache and its static marking, reveal
> levels with per-class thresholds, the portal impostor,
> the Love2D third view, and the chat window with the DM as its gate. Along with
> the open questions this conversation has raised and not settled — cache
> invalidation, mind as a field, the non-spatial group, whether an unrevealed
> doorway is distinguishable from a wall, which AI and
>   where, and what happens to phase 2's ray caster.
>
>   Shall I start on that, or do you want to keep talking the design out first?


wow, thirteen design phases? sounds like we're going to have to refactor. Go
ahead, write it up, then let's consider how to slim it down. This project should
have ~6 I reckon.

> The design has one part I would nail down early: the AI's tool surface should
> be the DM's own verbs and no others. The DM is delegating authority, so the AI
> should be incapable of anything the DM could not have done by hand. That makes
> the approval step meaningful — you are
> approving a request that will be executed with your permissions — and it
> makes the whole feature auditable, because every AI action lands in the
> command log like every other command and is undoable by the rollback that
> already exists.

right, like... every AI could tell that you can open a drawer. This one has a
lock on it, which the player AND THE AI learn when it's pulled and it's "open"
verb hits a 0 in the unlocked part of it's calculation equation. A*B+(1-A)*C
foreverrrr

> The case your answer does not cover is the non-spatial group. The ambush is
> four goblins in two rooms and a tripwire in a third, and structures are
> spatial and nested. Class thresholds might handle it — reveal creatures in
> both rooms at once — but only if the four goblins are the
>   only creatures there.

so, if a tripwire is pulled in one room and a specific kind of clattering noise
is heard, the goblins engage from four different angles at once, essentially
guaranteeing some hits on the ambushed? What's the question here, visibility?
the tripwire should be visible to those who check, and the goblins become
visible when they enter the room. Or enter a room that is visible to this one.
Same as all creatures.

> The rendering half — filling an unrevealed doorway with a surface derived
> from the boundary's own edge materials, so the unseen reads as a back face
> rather than as blackness — is a portal impostor, and the version you
> described has a property worth making explicit because the
> tempting alternative does not have it: it leaks nothing. The fill is composed
> from the edges of the boundary plane, and the boundary plane is already
> visible. If it were instead sampled from what lies behind the doorway, players
> would read the fill and learn about a room they have
> not entered. Your formulation is already the safe one. I want to know whether
> that was deliberate, because it is the kind of thing that gets "improved"
> later by somebody sampling the far side to make it look better.
>
> The question it raises: can a player tell an unrevealed doorway from a real
> wall? Drawn as a plausible surface, they cannot — which is either mystery,
> or four players walking repeatedly into what they believe is masonry. A faint
> difference, or nothing at all, is a decision rather
>   than an accident.


yes it's intentional. And yes they can. The "material" in this case wouldn't be
"interior wall of the doorway" but rather "a stone doorway shrouded in shadow"
which just means they get a texture that shows a doorway that they can't see
into because it's dark.

> This is a change from what I described last time and a good one. If reveals
> can ramp, and if a door opening or a candle going out is a sudden reversal,
> then reveal is a scalar per structure per viewer, and per-class thresholds are
> what make one number serve every kind of object at
> once. Set a room to 3 and the walls and furniture appear; the goblins have
> threshold 6 and stay hidden; the DM slides it to 7 and they walk out of the
> dark. One value, one comparison, and the DM never touches an individual
> creature.
>
> That is the thing that makes your goblin answer work, and it is why "gate by
> class at thresholds" is stronger than "gate each thing" — the DM turns one
> dial and every class sorts itself out.


this is a misunderstanding - I meant, visibility can slowly be revealed as a
character walks around a corner at a distance. I was picturing we'd do like, a
djikstra roll-down-the-hill pathfinding map, I forget what it's called but I'd
be interested to know, like a heat map or something that you calculate and
cache. Then, we can reveal visibility for each "tile" as the player walks
around.

--------------------------------------------------------------------------------

### Assistant Response 5

> Two things you said are more precise than you may realise, so let me answer
> those first, then write it up.

Now let me write it up.

--------------------------------------------------------------------------------

### User Request 6

Base directory for this skill:
/tmp/claude-1000/bundled-skills/2.1.236/78e956bf65855ceb029cecbc33d76258/claude-api

# Building LLM-Powered Applications with Claude

This skill helps you build LLM-powered applications with Claude. Choose the
right surface based on your needs, detect the project language, then read the
relevant language-specific documentation.

## Before You Start

Scan the target file (or, if no target file, the prompt and project) for
non-Anthropic provider markers — `import openai`, `from openai`,
`langchain_openai`, `OpenAI(`, `gpt-4`, `gpt-5`, file names like
`agent-openai.py` or `*-generic.py`, or any explicit instruction to keep the
code provider-neutral. If you find any, stop and tell the user that this skill
produces Claude/Anthropic SDK code; ask whether they want to switch the file to
Claude or want a non-Claude implementation. Do not edit a non-Anthropic file
with Anthropic SDK calls. (Exception: the `prompt-audit` subcommand is
non-interactive and does not stop here — it records non-Anthropic provider
markers in its report's stated assumptions and never proposes switching a
non-Anthropic file to the Anthropic SDK.)

## Output Requirement

When the user asks you to add, modify, or implement a Claude feature, your code
must call Claude through one of:

1. **The official Anthropic SDK** for the project's language (`anthropic`,
   `@anthropic-ai/sdk`, `com.anthropic.*`, etc.). This is the default whenever a
   supported SDK exists for the project.
2. **Raw HTTP** (`curl`, `requests`, `fetch`, `httpx`, etc.) — only when the
   user explicitly asks for cURL/REST/raw HTTP, the project is a shell/cURL
   project, or the language has no official SDK.

Never mix the two — don't reach for `requests`/`fetch` in a Python or
TypeScript project just because it feels lighter. Never fall back to
OpenAI-compatible shims.

**Never guess SDK usage.** Function names, class names, namespaces, method
signatures, and import paths must come from explicit documentation — either
the `{lang}/` files in this skill or the official SDK repositories or
documentation links listed in `shared/live-sources.md`. If the binding you need
is not explicitly documented in the skill files, WebFetch the relevant SDK repo
from `shared/live-sources.md` before writing code. Do not infer
Ruby/Java/Go/PHP/C# APIs from cURL shapes or from another language's SDK.

**If WebFetch or repository access fails** (network restricted, timeouts, clone
blocked): do not keep retrying — write code from the patterns and
namespace/package tables in the `{lang}/` file, run the compiler or interpreter
on it, and iterate on the error output. For statically-typed SDKs (C#, Java, Go)
a compile-fix loop against local errors reaches working code faster than blocked
network research.

## Defaults

Unless the user requests otherwise:

For the Claude model version, please use Claude Opus 5, which you can access via
the exact model string `claude-opus-5`. Please default to using adaptive
thinking (`thinking: {type: "adaptive"}`) for anything remotely complicated. And
finally, please default to streaming for any request that may involve long
input, long output, or high `max_tokens` — it prevents hitting request
timeouts. Use the SDK's `.get_final_message()` / `.finalMessage()` helper to get
the complete response if you don't need to handle individual stream events

## ⚠️ API Drift — Your Training Prior May Be Stale

Several common Claude API shapes changed in 2025–2026. If you recall a pattern
from training, verify it against the `{lang}/` files in this skill before
writing — the rows below are the most frequent drift points:

| Area | Stale prior | Current API |
|---|---|---|
| Extended thinking | `thinking: {type: "enabled", budget_tokens: N}` | On Claude 4.6+ models: `thinking: {type: "adaptive"}`. `budget_tokens` is deprecated on Opus 4.6 / Sonnet 4.6 and **rejected with a 400** on Fable 5 / Sonnet 5 / Opus 5 / 4.8 / 4.7. Pre-4.6 models still use `budget_tokens`. |
| Web search / web fetch tool type | `web_search_20250305`, `web_fetch_20250910` | `web_search_20260209`, `web_fetch_20260209` (dynamic filtering) on Opus 5/4.8/4.7/4.6, Sonnet 5, and Sonnet 4.6. Older models keep the basic variants; on Vertex AI only basic `web_search_20250305` is available (web fetch is not on Vertex) — see the Server Tools QR below. |
| PHP parameter names | snake_case wire names as named args (`max_tokens`) | Top-level named args are camelCase (`maxTokens`). Nested array keys vary by feature (e.g. `'taskBudget'`, `'skillID'`, `'mcp_server_name'`) — copy the exact key from the documented example; do not bulk-convert. |
| Managed Agents credentials | Keep secrets host-side via custom tools (the only option before vaults shipped) | Vault `environment_variable` credentials — stored by Anthropic, substituted at egress, never visible in the sandbox (`shared/managed-agents-tools.md` → Vaults). Host-side custom tools remain the fallback for self-hosted sandboxes. |

The `{lang}/` files in this skill are authoritative over recalled patterns.

---

## Subcommands

If the User Request at the bottom of this prompt is a bare subcommand string (no
prose), search every **Subcommands** table in this document — including any in
sections appended below — and follow the matching Action column directly. This
lets users invoke specific flows via `/claude-api <subcommand>`. If no table in
the document matches, treat the request as normal prose.

| Subcommand | Action |
|---|---|
| `migrate` | Migrate existing Claude API code to a newer model. **Read `shared/model-migration.md` immediately** and follow it in order: Step 0 (confirm scope — ask which files/directories before any edit), Step 1 (classify each file), then the per-target breaking-changes section. Do not summarize the guide — execute it. If the user did not name a target model, ask which model to migrate to in the same turn as the scope question. After the per-target changes are applied, audit the in-scope prompt text, tool descriptions, and request code against `shared/prompt-audit.md` — prompting written for the source model is part of every migration, and it does not announce itself. |
| `prompt-audit` | Audit existing prompts, skills, and tool descriptions for dated patterns ("cruft") written for older models. **Read `shared/prompt-audit.md` immediately** and follow it in order: Step 0 (establish scope and target model from the request and the repository — state the assumptions in the report, do not stop to ask), inventory, provenance, then the pattern scan. Produce both deliverables in full — the audit report (findings with `file:line`, pattern, why it's obsolete for the target model, confidence) and a proposed diff — without pausing for confirmation; apply edits only if the request explicitly asked for them. Do not summarize the guide — execute it. |
| `upgrade` | Upgrade the project's Anthropic SDK dependency across a major version — currently the Python SDK, `anthropic` 0.x → 1.x. Trailing words may name the language and/or a scope (`upgrade python`, `upgrade python sdk src/`). **Read `python/claude-api/sdk-upgrade.md` immediately** and follow it in order: Step 0 (confirm scope, then establish the current and target versions — a published 1.x must exist before you write a pin), the Step 1 inventory, each numbered section, then verification and the report. Do not summarize the guide — execute it. If the detected or named language has no `sdk-upgrade.md` in this skill, say that no major-version upgrade guide is bundled for that SDK yet and point the user at that SDK's CHANGELOG (repositories in `shared/live-sources.md`); do not improvise one from the Python guide. This is not model migration — to move code to a newer Claude model, use `migrate`. |

---

## Language Detection

Before reading code examples, determine which language the user is working in
(exception: for the `prompt-audit` subcommand, skip this section's ask steps —
the audit is non-interactive and its inventory is language-agnostic; when no
language is inferable, proceed without asking and state the assumption in the
report):

1. **Look at project files** to infer the language:

   - `*.py`, `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` →
     **Python** — read from `python/`
   - `*.ts`, `*.tsx`, `package.json`, `tsconfig.json` → **TypeScript** —
     read from `typescript/`
   - `*.js`, `*.jsx` (no `.ts` files present) → **TypeScript** — JS uses the
     same SDK, read from `typescript/`
   - `*.java`, `pom.xml`, `build.gradle` → **Java** — read from `java/`
   - `*.kt`, `*.kts`, `build.gradle.kts` → **Java** — Kotlin uses the Java
     SDK, read from `java/`
   - `*.scala`, `build.sbt` → **Java** — Scala uses the Java SDK, read from
     `java/`
   - `*.go`, `go.mod` → **Go** — read from `go/`
   - `*.rb`, `Gemfile` → **Ruby** — read from `ruby/`
   - `*.cs`, `*.csproj` → **C#** — read from `csharp/`
   - `*.php`, `composer.json` → **PHP** — read from `php/`

2. **If multiple languages detected** (e.g., both Python and TypeScript files):

   - Check which language the user's current file or question relates to
   - If still ambiguous, ask: "I detected both Python and TypeScript files.
     Which language are you using for the Claude API integration?"

3. **If language can't be inferred** (empty project, no source files, or
   unsupported language):

   - Use AskUserQuestion with options: Python, TypeScript, Java, Go, Ruby,
     cURL/raw HTTP, C#, PHP
   - If AskUserQuestion is unavailable, default to Python examples and note:
     "Showing Python examples. Let me know if you need a different language."

4. **If unsupported language detected** (Rust, Swift, C++, Elixir, etc.):

   - Suggest cURL/raw HTTP examples from `curl/` and note that community SDKs
     may exist
   - Offer to show Python or TypeScript examples as reference implementations

5. **If user needs cURL/raw HTTP examples**, read from `curl/`.

## Language-Specific Feature Support

Every SDK language above supports both the beta Tool Runner and Managed Agents
(beta) — Python (`@beta_tool` decorator), TypeScript (`betaZodTool` + Zod),
Java (annotated classes), Go (`BetaToolRunner` in the `toolrunner` pkg), Ruby
(`BaseTool` + `tool_runner`), C# (`BetaToolRunner` + raw JSON schema), PHP
(`BetaRunnableTool` + `toolRunner()`); code entry points are in the Tool Use
Patterns quick reference below. cURL is raw HTTP (no SDK features) and supports
Managed Agents.

> **Managed Agents code examples**: see the reading guide in the `## Managed
> Agents (Beta)` section below.

---

## Which Surface Should I Use?

> **Start simple.** Default to the simplest tier that meets your needs. Single
> API calls and workflows handle most use cases — only reach for agents when
> the task genuinely requires open-ended, model-driven exploration. "Simplest"
> means the least code you own: for a hosted, scheduled, or memory-backed agent,
> Managed Agents is usually the simplest option (no loop code, no state files,
> no scheduler), even though it's a bigger platform.

| Use Case                                        | Tier            | Recommended Surface       | Why                                                          |
| ----------------------------------------------- | --------------- | ------------------------- | ------------------------------------------------------------ |
| Classification, summarization, extraction, Q&A  | Single LLM call | **Claude API**            | One request, one response                                    |
| Batch processing or embeddings                  | Single LLM call | **Claude API**            | Specialized endpoints                                        |
| Multi-step pipelines with code-controlled logic | Workflow        | **Claude API + tool use** | You orchestrate the loop                                     |
| Custom agent with your own tools                | Agent           | **Claude API + tool use** | Maximum flexibility                                          |
| Server-managed stateful agent with workspace    | Agent           | **Managed Agents**        | Anthropic runs the loop and hosts the tool-execution sandbox |
| Persisted, versioned agent configs              | Agent           | **Managed Agents**        | Agents are stored objects; sessions pin to a version         |
| Long-running multi-turn agent with file mounts  | Agent           | **Managed Agents**        | Per-session containers, SSE event stream, Skills + MCP       |
| Agent that runs on a schedule (cron, "every night") | Agent       | **Managed Agents** — scheduled deployments | Deployments fire sessions autonomously; no client-side scheduler |

> **Note:** Managed Agents is the right choice when you want Anthropic to run
> the agent loop *and* host the container where tools execute — file ops,
> bash, code execution all run in the per-session workspace. If you want to host
> the compute yourself or run your own custom tool runtime, Claude API + tool
> use is the right choice — use the tool runner for the agentic loop — its
> per-turn hooks still give you approval gates, logging, error interception, and
> conditional execution (see `shared/tool-use-concepts.md`) — or the manual
> loop when you want to own the entire loop yourself.

> **Cloud-provider access.** **Claude Platform on AWS** is Anthropic-operated
> with same-day API parity — see `shared/claude-platform-on-aws.md` for client
> setup. For per-feature availability on **Claude Platform on AWS**, **Amazon
> Bedrock**, **Google Vertex AI**, and **Microsoft Foundry**, see
> `shared/platform-availability.md` — that table is the single source of truth
> in this skill; do not infer availability from anywhere else.

## Building an Agent: Four Approaches

Once you've decided you actually need an agent (open-ended, model-driven tool
use), there are four distinct ways to build one. Two independent questions
separate them: **who supplies the harness** (the agent loop + context
management) and **who supplies the deployment** (the infra the agent runs on).
The Tool Runner and the Claude Agent SDK both supply a *harness only* — you
still host and deploy them yourself — which is why they're easy to conflate.
Managed Agents (CMA) is the only option that supplies **both** the harness *and*
managed deployment; the manual loop supplies neither.

| # | Approach | You write | Harness & deployment | Tools available | Use when |
|---|----------|-----------|----------------------|-----------------|----------|
| 1 | **Claude API — manual loop** | The `while stop_reason == "tool_use"` loop yourself | You build the harness; you host | Only tools you define | You want to own the *entire* loop — no beta dependency, or a control flow the Tool Runner's per-turn hooks don't fit |
| 2 | **Claude API — Tool Runner** (`client.beta.messages.tool_runner` + `@beta_tool` / `betaZodTool`) | Just the tool functions | SDK supplies the loop (**harness only**); you host | Only tools you define | A custom-tool agent without hand-writing the loop (most cases). Per-turn hooks still give you approval gates, error interception, result modification (e.g. `cache_control`), retries, streaming, and compaction |
| 3 | **Managed Agents** (REST, beta) | Agent config + your tool results | Anthropic supplies the harness **and** hosts a per-session sandbox (**harness + deployment**) | Anthropic-hosted sandbox (bash, files, code exec) + Skills/MCP + your tools | You want Anthropic to run the loop *and* host the per-session workspace; persisted/versioned configs; long-running sessions |
| 4 | **Claude Agent SDK** — *separate product* (`claude-agent-sdk` / `@anthropic-ai/claude-agent-sdk`) | A prompt + options | SDK supplies the Claude Code harness + built-in tools (**harness only**); you host | Built-in Read/Write/Edit/Bash/Glob/Grep/WebSearch/WebFetch + MCP + subagents | You want a batteries-included coding/filesystem agent running on your own infra |

The harness/deployment split is the key mental model: options 1, 2, and 4 all
**leave deployment to you**; only option 3 (CMA) adds managed deployment.
Options 1–3 are what this skill generates; option 4 is a different library
with its own docs — see the disambiguation below.

> **Tool Runner ≠ Claude Agent SDK.** These sound alike but are different
> packages:
> - **Tool Runner** is part of the regular Anthropic API SDK (`anthropic` /
> `@anthropic-ai/sdk`), reached via `client.beta.messages.tool_runner`. It
> automates the request → execute → loop cycle *for tools you define*. No
> built-in tools, no filesystem access, no sandbox — you supply every tool and
> host the compute. It is option 2 above, a thin helper over `POST
> /v1/messages`.
> - **Claude Agent SDK** (`claude-agent-sdk` / `@anthropic-ai/claude-agent-sdk`)
> is Claude Code packaged as a library. It ships built-in tools (file
> read/write/edit, bash, grep, web search), the full agent loop, context
> management, hooks, subagents, permissions, and sessions. You call
> `query(prompt, options)` and it drives everything.
>
> Both are **harness-only — you host and deploy them.** The difference is
> scope of harness: the Tool Runner loops over tools *you* define (with per-turn
> hooks for approval, interception, result modification, and retries — but no
> built-in tools); the Agent SDK is the full Claude Code harness with built-in
> tools. Neither provides managed deployment — that's what **Managed Agents
> (CMA)** adds (Anthropic hosts the loop and a per-session sandbox).
>
> **This skill covers the Claude API and Managed Agents (options 1–3); it does
> not generate Claude Agent SDK code.** If the user actually wants the Claude
> Agent SDK, point them to its docs (`code.claude.com/docs/en/agent-sdk`) —
> don't substitute the API Tool Runner for it, or vice-versa.

## Should I Build an Agent?

Before choosing the agent tier, check all four criteria:

- **Complexity** — Is the task multi-step and hard to fully specify in
  advance? (e.g., "turn this design doc into a PR" vs. "extract the title from
  this PDF")
- **Value** — Does the outcome justify higher cost and latency?
- **Viability** — Is Claude capable at this task type?
- **Cost of error** — Can errors be caught and recovered from? (tests, review,
  rollback)

If the answer is "no" to any of these, stay at a simpler tier (single call or
workflow).

---

## Architecture

Everything goes through `POST /v1/messages`. Tools and output constraints are
features of this single endpoint — not separate APIs.

**User-defined tools** — You define tools (via decorators, Zod schemas, or raw
JSON), and the SDK's tool runner handles calling the API, executing your
functions, and looping until Claude is done. For full control, you can write the
loop manually.

**Server-side tools** — Anthropic-hosted tools that run on Anthropic's
infrastructure. Code execution is fully server-side (declare it in `tools`,
Claude runs code automatically). Computer use can be server-hosted or
self-hosted.

**Structured outputs** — Constrains the Messages API response format
(`output_config.format`) and/or tool parameter validation (`strict: true`). The
recommended approach is `client.messages.parse()` which validates responses
against your schema automatically. Note: the old `output_format` parameter is
deprecated; use `output_config: {format: {...}}` on `messages.create()`.

**Supporting endpoints** — Batches (`POST /v1/messages/batches`), Files (`POST
/v1/files`), Token Counting (`POST /v1/messages/count_tokens` — see
`shared/token-counting.md`), and Models (`GET /v1/models`, `GET /v1/models/{id}`
— live capability/context-window discovery) feed into or support Messages API
requests.

---

## Current Models (cached: 2026-06-24)

| Model             | Model ID            | Context        | Input $/1M | Output $/1M |
| ----------------- | ------------------- | -------------- | ---------- | ----------- |
| Claude Fable 5    | `claude-fable-5`      | 1M             | $10.00     | $50.00      |
| Claude Mythos 5 (Project Glasswing only) | `claude-mythos-5` | 1M | $10.00     | $50.00      |
| Claude Opus 5     | `claude-opus-5`       | 1M             | $5.00      | $25.00      |
| Claude Opus 4.8 | `claude-opus-4-8`  | 1M             | $5.00      | $25.00      |
| Claude Opus 4.7   | `claude-opus-4-7`   | 1M             | $5.00      | $25.00      |
| Claude Opus 4.6   | `claude-opus-4-6`   | 1M             | $5.00      | $25.00      |
| Claude Sonnet 5   | `claude-sonnet-5`   | 1M             | $3.00 ($2.00 intro through 2026-08-31) | $15.00 ($10.00 intro) |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | 1M             | $3.00      | $15.00      |
| Claude Haiku 4.5  | `claude-haiku-4-5`  | 200K           | $1.00      | $5.00       |

**Partner pricing:** The prices above are Anthropic first-party API rates —
they also apply to Claude on Microsoft Foundry, which is billed through the
Microsoft Marketplace at standard API rates. Claude on Amazon Bedrock and Vertex
AI is partner-operated with separate pricing — see
[Bedrock](https://aws.amazon.com/bedrock/pricing/) or [Vertex
AI](https://cloud.google.com/vertex-ai/generative-ai/pricing#claude-models). For
WebFetch, use the Pricing row in `shared/live-sources.md`.

**ALWAYS use `claude-opus-5` unless the user explicitly names a different
model.** This is non-negotiable. Do not use `claude-sonnet-5`,
`claude-sonnet-4-6`, or any other model unless the user literally says "use
sonnet" or "use haiku". Never downgrade for cost — that's the user's decision,
not yours. Use `claude-fable-5` only when the user explicitly asks for Claude
Fable 5, "fable", or Anthropic's most capable model — it has different API
behavior than the Opus family (see below) and pricing that exceeds Opus-tier.
**Use only the exact model ID strings from the table — they are complete
as-is; never append date suffixes** (`claude-sonnet-4-6`, never
`claude-sonnet-4-6-20251114` or any other date-suffixed variant you might recall
from training data). If the user requests an older model not in the table (e.g.,
"opus 4.5", "sonnet 3.7"), read `shared/models.md` for the exact ID — do not
construct one yourself.

## Claude Fable 5 (`claude-fable-5`) — most capable widely released model

Claude Fable 5 is Anthropic's most capable widely released model, for the most
demanding reasoning and long-horizon agentic work; everything below also applies
to **Claude Mythos 5** (`claude-mythos-5`, Project Glasswing — same
capabilities, pricing, and API surface; successor to the invitation-only
`claude-mythos-preview`). 1M context window (the maximum is also the default),
128K max output. Key API differences from Opus-tier — see
`shared/model-migration.md` → Migrating to Claude Fable 5 for details:

- **Thinking is always on** — omit the `thinking` parameter entirely (or send
  `{type: "adaptive"}`). Any other explicit configuration is rejected: `{type:
  "disabled"}` and `{type: "enabled", budget_tokens: N}` both return a 400.
  Control depth with `output_config.effort` (supports `low` through `xhigh` and
  `max`).
- **The raw chain of thought is never returned** — responses carry regular
  `thinking` blocks (not `redacted_thinking`): `display: "summarized"` returns a
  readable summary, `"omitted"` (the default) leaves the `thinking` field as an
  empty string. Replay rules: pass thinking blocks back unchanged on the same
  model; other models drop them silently (unbilled — nothing to strip);
  details in `shared/model-migration.md`.
- **Tokenizer** — same tokenizer as Opus 4.8 (introduced with Opus 4.7). Token
  counts are roughly unchanged when migrating from Opus 4.7/4.8; per-token
  pricing differs. Coming from Opus 4.6, Sonnet, Haiku, or older, re-baseline
  with `count_tokens` (the Opus 4.7 tokenizer uses ~1×–1.35× as many
  tokens).
- **`refusal` stop reason — handle it, and opt into fallbacks by default** —
  safety classifiers may decline a request (HTTP 200, `stop_reason: "refusal"`,
  with a `stop_details` category); always check `stop_reason` before reading
  `content`. **When you write `claude-fable-5` or `claude-opus-5` code, include
  the server-side `fallbacks` parameter by default.** Simplest form: `betas:
  ["server-side-fallback-2026-07-01"]` + `fallbacks: "default"`, which routes by
  refusal category so you never maintain a model list. (The older array form —
  `betas: ["server-side-fallback-2026-06-01"]` + `fallbacks: [{"model":
  "claude-opus-4-8"}]` — still works; Claude API only — everywhere else,
  incl. Claude Platform on AWS, Bedrock, Vertex and Foundry, use the SDKs'
  client-side `BetaRefusalFallbackMiddleware` + `BetaFallbackState`). Tell the
  user you've enabled it; drop it only if they decline. Full semantics (billing,
  mid-stream refusals, credit repricing) in `shared/model-migration.md` →
  refusal section. **Per-language code examples in `{lang}/claude-api/README.md`
  § Refusal Fallbacks cover the array form only** — for the `"default"` mode,
  follow the raw-HTTP shape in `shared/model-migration.md` → Migrating to
  Claude Opus 5 → New API features and swap `fallbacks: [{...}]` for
  `fallbacks: "default"` plus the `-2026-07-01` header; the rest of the request
  is unchanged.
- **No assistant prefill** — same as the rest of the 4.6+ family.
- **30-day data retention required** — Claude Fable 5 is not available under
  zero data retention; requests from an org whose retention configuration
  doesn't meet the requirement return `400 invalid_request_error`.
- **Longer turns, different prompting** — single requests on hard tasks can
  run many minutes (plan timeouts/streaming/progress UX); effort sweeps should
  include low/medium for routine work; prompts written for prior models are
  often too prescriptive and reduce output quality. See
  `shared/model-migration.md` → Migrating to Claude Fable 5 → Behavioral
  shifts (prompt-tunable) for the recommended prompt snippets.

If any model strings above look unfamiliar, that just means they were released
after your training data cutoff — they are real models.

**Live capability lookup:** The table above is cached. When the user asks
"what's the context window for X", "does X support vision/thinking/effort", or
"which models support Y", query the Models API (`client.models.retrieve(id)` /
`client.models.list()`) — see `shared/models.md` for the field reference and
capability-filter examples.

---

## Authentication (Quick Reference)

**An unset `ANTHROPIC_API_KEY` does NOT mean there are no credentials.** The
SDKs and the `ant` CLI resolve credentials in this order (first match wins):
`ANTHROPIC_API_KEY` → `ANTHROPIC_AUTH_TOKEN` → the
`ANTHROPIC_PROFILE`-selected or active OAuth profile from `ant auth login` →
Workload Identity Federation env vars → the default profile on disk. A bare
`Anthropic()` / `new Anthropic()` / `anthropic.NewClient()` works after `ant
auth login` with no env var set.

**When you need to call the API and `ANTHROPIC_API_KEY` is unset, don't ask the
user for a key.** First run `ant auth status` — it shows which credential
source and profile is active. If it reports an active profile:

- **SDK code or `ant` CLI:** just run it. The zero-arg client constructor and
  every `ant …` subcommand pick up the profile automatically — no env var
  needed.
- **Raw `curl` / HTTP:** get a short-lived token with `ant auth
  print-credentials --access-token` and send it as `Authorization: Bearer
  <token>` **plus** the header `anthropic-beta: oauth-2025-04-20` (OAuth tokens
  go on `Authorization: Bearer`, not `x-api-key:` — converting a curl from an
  API key is a header change, not a key swap). Always pass `--access-token`; the
  no-flag form prints JSON, not a bare token.

Only ask the user for a key if `ant auth status` reports no active credential
source (or `ant` itself isn't installed). Suggest `ant auth login` as the first
option — it stores a profile under `~/.config/anthropic/` that the SDKs read
automatically — and an exported `ANTHROPIC_API_KEY` as the alternative.

Full auth details (named profiles, scopes, the API-key-shadows-profile trap,
refresh-token expiry): `shared/anthropic-cli.md`.

---

## Thinking & Effort (Quick Reference)

Use adaptive thinking (`thinking: {type: "adaptive"}`) on every current model
— Claude dynamically decides when and how much to think. Per-model rules:

| Model | Thinking config | Omitting `thinking` | `budget_tokens` | Sampling (`temperature`/`top_p`/`top_k`) | Effort levels |
|---|---|---|---|---|---|
| Fable 5 | `{type: "adaptive"}` or omit; explicit `{type: "disabled"}` returns 400 — omit the param instead | Runs adaptive (thinking is always on) | Removed — `{type: "enabled", budget_tokens: N}` returns 400 | Removed — 400 | `low`/`medium`/`high`/`xhigh`/`max` |
| Claude Opus 5 | `{type: "adaptive"}` or omit; `{type: "disabled"}` accepted **only at effort `high` or below** — 400 at `xhigh`/`max`, and see the disabled-thinking pitfall below | Runs **adaptive** (thinking is on by default — unlike Opus 4.8/4.7) | Removed — 400 | Removed — 400 | `low`–`max` (all five) |
| Opus 4.8 / 4.7 | `{type: "adaptive"}` is the only on-mode; `{type: "disabled"}` accepted | Runs **without** thinking — set `{type: "adaptive"}` explicitly | Removed — 400 | Removed — 400 | `low`/`medium`/`high`/`xhigh`/`max` |
| Sonnet 5 | `{type: "adaptive"}` is the only on-mode; `{type: "disabled"}` accepted | Runs adaptive | Removed — 400 | Removed — 400 | `low`/`medium`/`high`/`xhigh`/`max` |
| Opus 4.6 / Sonnet 4.6 | `{type: "adaptive"}` (recommended; auto-enables interleaved thinking, no beta header) | Set `{type: "adaptive"}` explicitly | Deprecated — do not use in new code; transitional escape hatch only (see below) | Allowed | `low`/`medium`/`high`/`max` (`xhigh` arrived with Opus 4.7) |
| Older (Sonnet 4.5, Haiku 4.5, …) — only if explicitly requested | `{type: "enabled", budget_tokens: N}` | No thinking | Required for thinking; must be less than `max_tokens`, minimum 1024 — errors otherwise | Allowed | `effort` works on Opus 4.5 (`low`/`medium`/`high` only — no `xhigh`/`max`); errors on Sonnet 4.5 / Haiku 4.5 |

Opus 4.8 keeps the same request surface as 4.7 (no new breaking changes) — see
`shared/model-migration.md` → Migrating to Opus 4.8 for the behavioral
re-tuning, and → Migrating to Opus 4.7 for the full breaking-change list when
coming from 4.6 or earlier. With `thinking` disabled, Opus 4.8 may write longer
reasoning into the visible response — leave adaptive thinking on, or add a
final-answer-only instruction (see the migration guide).

- **Effort (GA, no beta header):** `output_config: {effort:
  "low"|"medium"|"high"|"xhigh"|"max"}` — inside `output_config`, not
  top-level; default `high` (equivalent to omitting it). Controls thinking depth
  and overall token spend; combine with adaptive thinking for the best
  cost-quality tradeoffs. `xhigh` (added on Opus 4.7, between `high` and `max`)
  is the best setting for most coding and agentic use cases on Fable 5 / Opus
  4.7/4.8 / Sonnet 5, and the default in Claude Code; effort matters more on
  those models than on any prior model in their tier — re-tune it when
  migrating, and run long-horizon/agentic tasks at `high`/`xhigh` with the full
  task spec given up front. Use a minimum of `high` for intelligence-sensitive
  work, `max` when correctness matters more than cost, and `low` for subagents
  or simple tasks — lower effort means fewer and more-consolidated tool calls,
  less preamble, and terser confirmations (`high` is often the sweet spot
  balancing quality and token efficiency).
- **Thinking display — `"omitted"` by default on Fable 5 / Mythos 5 / Opus 5 /
  4.8 / 4.7 / Sonnet 5:** `display: "summarized"` returns a readable summary of
  the reasoning; `"omitted"` (the default on all six — a silent change from
  Opus 4.6 and Sonnet 4.6, where it was `"summarized"`) streams `thinking`
  blocks with empty text. `display` controls visibility only — thinking
  happens and is billed the same under every setting; the raw chain of thought
  is never exposed on any model. If you stream reasoning to users, the default
  looks like a long pause before output — set `thinking: {type: "adaptive",
  display: "summarized"}` explicitly. (Independent of display, echo thinking
  blocks back unchanged when continuing on the same model; other models silently
  ignore them — see the migration guide.)
- **When the user asks for "extended thinking", a "thinking budget", or
  `budget_tokens`:** always use Fable 5, Opus 5, 4.8, 4.7, or 4.6 with
  `thinking: {type: "adaptive"}` — the fixed thinking-token-budget concept is
  deprecated and adaptive thinking replaces it. Do NOT use `budget_tokens` for
  new 4.6/4.7/4.8 code and do NOT switch to an older model just because the user
  mentions it. *Gradual-migration carve-out:* `budget_tokens` is still
  functional on Opus 4.6 and Sonnet 4.6 only, as a transitional escape hatch for
  existing code that needs a hard token ceiling before you've tuned `effort` —
  see `shared/model-migration.md` → Transitional escape hatch. It is fully
  removed on Fable 5, Opus 5/4.7/4.8, and Sonnet 5.

---

## Compaction (Quick Reference)

**Beta, Fable 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5, and Sonnet
4.6.** For long-running conversations that may exceed the 1M context window,
enable server-side compaction. The API automatically summarizes earlier context
when it approaches the trigger threshold (default: 150K tokens). Requires beta
header `compact-2026-01-12`.

**Critical:** Append `response.content` (not just the text) back to your
messages on every turn. Compaction blocks in the response must be preserved —
the API uses them to replace the compacted history on the next request.
Extracting only the text string and appending that will silently lose the
compaction state.

See `{lang}/claude-api/README.md` (Compaction section) for code examples. Full
docs via WebFetch in `shared/live-sources.md`.

---

## Prompt Caching (Quick Reference)

**Prefix match.** Any byte change anywhere in the prefix invalidates everything
after it. Render order is `tools` → `system` → `messages`. Keep stable
content first (frozen system prompt, deterministic tool list), put volatile
content (timestamps, per-request IDs, varying questions) after the last
`cache_control` breakpoint.

**Mid-conversation operator instructions** (Claude Opus 5, Claude Opus 4.8,
Claude Fable 5, Claude Mythos 5; not Claude Sonnet 5; no beta header): append
`{"role": "system", ...}` to `messages[]` instead of editing top-level `system`.
Preserves the cached history prefix and is the prompt-injection-safe operator
channel. See `shared/prompt-caching.md` § Mid-conversation system messages.

**Top-level auto-caching** (`cache_control: {type: "ephemeral"}` on
`messages.create()`) is the simplest option when you don't need fine-grained
placement. Max 4 breakpoints per request. Minimum cacheable prefix is ~1024
tokens — shorter prefixes silently won't cache.

**Verify with `usage.cache_read_input_tokens`** — if it's zero across repeated
requests, a silent invalidator is at work (`datetime.now()` in system prompt,
unsorted JSON, varying tool set).

For placement patterns, architectural guidance, and the silent-invalidator audit
checklist: read `shared/prompt-caching.md`. Language-specific syntax:
`{lang}/claude-api/README.md` (Prompt Caching section).

---

## Fast Mode (Quick Reference)

**Research preview, Claude Opus 5 / Opus 4.8 only** — Claude API and Managed
Agents, not Bedrock / Google Cloud / Foundry. Opus 4.7 fast mode has been
removed: `speed: "fast"` on 4.7 returns an error. Fast mode on Claude Opus 5 is
priced at $10 / $50 per MTok. Fast mode runs the same model at up to 2.5x higher
output tokens per second, at premium pricing. Three things are required on every
request: use the **beta** messages endpoint (`client.beta.messages.…`), pass
the beta flag `fast-mode-2026-02-01`, and set `speed: "fast"` as a top-level
request parameter (not a header, not in `extra_body`).

```python
client.beta.messages.create(
    model="claude-opus-5", max_tokens=4096,
    speed="fast", betas=["fast-mode-2026-02-01"],
    messages=[...],
)
```

| Language | Beta flag | Speed parameter |
|---|---|---|
| Python | `betas=["fast-mode-2026-02-01"]` | `speed="fast"` |
| TypeScript / Ruby | `betas: ["fast-mode-2026-02-01"]` | `speed: "fast"` |
| Go | `[]anthropic.AnthropicBeta{anthropic.AnthropicBetaFastMode2026_02_01}` | `Speed: anthropic.BetaMessageNewParamsSpeedFast` |
| Java | `.addBeta(AnthropicBeta.FAST_MODE_2026_02_01)` | `.speed(MessageCreateParams.Speed.FAST)` |
| C# | `Betas = ["fast-mode-2026-02-01"]` | `Speed = Speed.Fast` (`Anthropic.Models.Beta.Messages`) |
| PHP | `betas: ['fast-mode-2026-02-01']` | `speed: 'fast'` |
| cURL | `anthropic-beta: fast-mode-2026-02-01` header | `"speed": "fast"` in body |

`response.usage.speed` reports which speed was used. Fast mode has its own rate
limit separate from standard Opus; on 429, either retry after the `retry-after`
delay or drop `speed` and fall back to standard (note: switching speed
invalidates prompt cache). Not available with Batch API, Priority Tier, Claude
Platform on AWS, or third-party platforms.

**Priority Tier does not cover Claude Opus 5.** It is supported on every other
current model, including Claude Fable 5 and Opus 4.8, but Claude Opus 5, Claude
Sonnet 5, Claude Mythos 5, and Mythos Preview are excluded — a Priority Tier
request naming one of them fails validation.

---

## Task Budgets (Quick Reference)

**Beta, Claude Opus 5 / Fable 5 / Sonnet 5 / Opus 4.8 / 4.7.** A task budget
gives Claude a token ceiling for an agentic loop so it paces itself and finishes
gracefully instead of being cut off — distinct from `max_tokens`, which is an
enforced per-response ceiling the model is not aware of. Minimum `total`:
20,000. Set `task_budget` inside `output_config` on
`client.beta.messages.stream(...)` with beta flag `task-budgets-2026-03-13` —
use streaming so the large `max_tokens` doesn't hit HTTP timeouts (full details:
`shared/model-migration.md` → Task Budgets):

```python
with client.beta.messages.stream(
    model="claude-opus-5", max_tokens=128000,
    output_config={"effort": "high", "task_budget": {"type": "tokens", "total": 64000}},
    betas=["task-budgets-2026-03-13"],
    messages=[...], tools=[...],
) as stream:
    response = stream.get_final_message()
```

`task_budget` fields: `type` (always `"tokens"`), `total`, and optional
`remaining` (defaults to `total`). The server injects a countdown marker Claude
sees during generation; the budget counts what Claude generates and the tool
results it reads this turn — **not** the full history you resend each request.
Not the same thing as **Managed Agents session budgets** — those are hard,
dollar-denominated, platform-enforced caps on one CMA session
(`shared/managed-agents-core.md` § Session budgets); a task budget is advisory
and token-denominated.

**Observing spend:** accumulate `response.usage.output_tokens` (plus the token
count of the tool-result blocks you append) across loop iterations if you want
to display progress. Leave `remaining` unset in the normal loop — the server
tracks the countdown itself, and passing a client-computed `remaining` while
also resending full history under-reports the budget. **Only pass `remaining`**
when you compact or rewrite history between requests and the server can no
longer derive prior spend.

---

## Provider Clients (Quick Reference)

When targeting Claude on a third-party platform, use that platform's dedicated
client class — not the first-party `Anthropic()` client with a `base_url`
override. After construction the client exposes the same `messages.create` /
`.stream` surface as the first-party SDK.

## Amazon Bedrock

Use the **Mantle** client (Messages-API Bedrock endpoint). Bedrock model IDs
take an `anthropic.` prefix (e.g. `"anthropic.claude-opus-5"`). Region is
required.

| Language | Client |
|---|---|
| Python | `from anthropic import AnthropicBedrockMantle` → `AnthropicBedrockMantle(aws_region="…")` |
| TypeScript | `import { AnthropicBedrockMantle } from "@anthropic-ai/bedrock-sdk"` → `new AnthropicBedrockMantle({ awsRegion: "…" })` |
| Go | `bedrock.NewMantleClient(ctx, bedrock.MantleClientConfig{ AWSRegion: "…" })` |
| Java | `AnthropicOkHttpClient.builder().backend(BedrockMantleBackend.fromEnv()).build()` (from `com.anthropic.bedrock.backends`) |
| C# | `new AnthropicBedrockMantleClient(new() { AwsRegion = "…" })` (package `Anthropic.Bedrock`) |
| PHP | `use Anthropic\Bedrock\MantleClient;` → `new MantleClient(awsRegion: '…')` |
| Ruby | `Anthropic::BedrockMantleClient.new(aws_region: "…")` |

`AnthropicBedrock` / `BedrockClient` / `BedrockBackend` (without `Mantle`) are
the legacy `bedrock-runtime` InvokeModel path — prefer the Mantle client for
new code.

## Microsoft Foundry

| Language | Client |
|---|---|
| Python | `from anthropic import AnthropicFoundry` → `AnthropicFoundry(api_key=…, resource="…")` |
| TypeScript | `import AnthropicFoundry from "@anthropic-ai/foundry-sdk"` → `new AnthropicFoundry({ … })` |
| Java | `AnthropicOkHttpClient.builder().backend(FoundryBackend.fromEnv()).build()` (from `com.anthropic.foundry.backends`) |
| C# | `new AnthropicFoundryClient(new AnthropicFoundryApiKeyCredentials(…))` (package `Anthropic.Foundry`) |
| PHP | `Foundry\Client::withCredentials(…)` |

The Go and Ruby SDKs do not currently support Foundry. For Ruby, use the
standard `Anthropic::Client.new(base_url: "<foundry endpoint>")` as a fallback
(Entra ID auth is not built in). For Claude Platform on AWS, see
`shared/claude-platform-on-aws.md`.

## Google Cloud Vertex AI

Two required constructor args: GCP `project_id` and `region`. Vertex model IDs
take **no prefix** — current-generation models (Opus 4.8/4.7/4.6, Sonnet 5,
Sonnet 4.6) use the bare first-party ID (e.g. `"claude-opus-5"`); dated-snapshot
models use an `@` version separator (e.g. `claude-opus-4-5@20251101`, **not**
`claude-opus-4-5-20251101`). Auth is GCP ADC (`gcloud auth application-default
login`); no Anthropic API key. `region` can be `"global"` (recommended), a
multi-region (`"us"`/`"eu"`), or a specific region. After construction, use the
same `messages.create` / `.stream` surface.

| Language | Client |
|---|---|
| Python | `from anthropic import AnthropicVertex` → `AnthropicVertex(project_id="…", region="…")` (install `"anthropic[vertex]"`) |
| TypeScript | `import { AnthropicVertex } from "@anthropic-ai/vertex-sdk"` → `new AnthropicVertex({ projectId, region })` |
| Go | `import "github.com/anthropics/anthropic-sdk-go/vertex"` → `anthropic.NewClient(vertex.WithGoogleAuth(ctx, region, projectID))` |
| Java | `AnthropicOkHttpClient.builder().backend(VertexBackend.builder().region("…").project("…").build()).build()` (from `com.anthropic.vertex.backends`) |
| C# | `new AnthropicClient { Backend = new VertexBackend(projectId, region) }` (package `Anthropic.Vertex`) |
| PHP | `use Anthropic\Vertex;` → `Vertex\Client::fromEnvironment(location: '…', projectId: '…')` — note `location`, not `region` |
| Ruby | `Anthropic::VertexClient.new(region: "…", project_id: "…")` |

---

## Context Editing (Quick Reference)

**Beta.** Context editing **clears** old tool results or thinking blocks from
the conversation before the model sees it; it is **not compaction** (which
summarizes). On `client.beta.messages.*` with beta
`context-management-2025-06-27`, pass `context_management.edits` with a strategy
type:

```python
client.beta.messages.create(
    model="claude-opus-5", max_tokens=4096,
    betas=["context-management-2025-06-27"],
    context_management={"edits": [{"type": "clear_tool_uses_20250919"}]},
    tools=[...], messages=[...],
)
```

Strategy types: `clear_tool_uses_20250919` (clears old tool results; optional
`clear_tool_inputs: true` also clears the tool_use params) and
`clear_thinking_20251015` (clears thinking blocks). Do **not** use
`compact_20260112` or beta `compact-2026-01-12` — those are the separate
compaction feature.

---

## Mid-Conversation System Messages (Quick Reference)

**Claude Opus 5, Claude Opus 4.8, Claude Fable 5, and Claude Mythos 5; not
Claude Sonnet 5; no beta header.** Append `{"role": "system", "content": "…"}`
to the `messages` array (not the top-level `system` field) to add an operator
instruction mid-conversation without invalidating the cached prefix. Use the
regular `client.messages.create` — there is no beta. A mid-conversation system
message must follow a `user` message (or an `assistant` message ending in
server-tool use), and must be either the last entry in `messages` or be followed
by an `assistant` turn — it cannot be `messages[0]`. Availability:
`shared/platform-availability.md`. See `shared/prompt-caching.md` §
Mid-conversation system messages.

---

## Managed Agents (Beta)

**Managed Agents** is a third surface: server-managed stateful agents with
Anthropic-hosted tool execution. You create a persisted, versioned Agent config
(`POST /v1/agents`), then start Sessions that reference it. Each session
provisions a container as the agent's workspace — bash, file ops, and code
execution run there; the agent loop itself runs on Anthropic's orchestration
layer and acts on the container via tools. The session streams events; you send
messages and tool results back.

Availability: `shared/platform-availability.md`. For agents on Bedrock / Vertex
/ Foundry (where Managed Agents is unsupported), use Claude API + tool use.

**Mandatory flow:** Agent (once) → Session (every run).
`model`/`system`/`tools` live on the agent, never the session. See
`shared/managed-agents-overview.md` for the full reading guide, beta headers,
and pitfalls.

**Beta headers:** `managed-agents-2026-04-01` — the SDK sets this
automatically for all
`client.beta.{agents,environments,sessions,vaults,memory_stores,deployments,deployment_runs}.*`
calls. Skills API uses `skills-2025-10-02` and Files API uses
`files-api-2025-04-14`, but you don't need to explicitly pass those in for
endpoints other than `/v1/skills` and `/v1/files`.

**Subcommands** — invoke directly with `/claude-api <subcommand>`:

| Subcommand | Action |
|---|---|
| `managed-agents-onboard` | Walk the user through setting up a Managed Agent from scratch. **Read `shared/managed-agents-onboarding.md` immediately** and follow its interview script: **describe → configure the agent (propose, don't interrogate) → environment → session** (same arc as the Console quickstart, auth deferred to the session step) — defaults and inline suggestions do the work, with a silent viability gate (job vs tools/credentials/data) before any code is emitted. Do not summarize — run the interview. |

**Reading guide:** Start with `shared/managed-agents-overview.md`, then the
topical `shared/managed-agents-*.md` files (core, environments, tools, events,
outcomes, multiagent, webhooks, memory, scheduled-deployments, client-patterns,
onboarding, api-reference). For Python, TypeScript, Go, Ruby, PHP, and Java,
read `{lang}/managed-agents/README.md` for code examples. For cURL, read
`curl/managed-agents.md`. **Agents are persistent — create once, reference by
ID.** Define agents and environments as version-controlled YAML applied with the
`ant` CLI — this is the recommended flow (see `shared/anthropic-cli.md`): the
CLI owns the control plane (creating and updating agents), your code owns the
data plane (`sessions.create` with the stored agent ID). Call `agents.create()`
in code only when you must provision programmatically; either way, store the
returned agent ID and pass it to every subsequent `sessions.create`; never call
`agents.create()` in the request path. If a binding you need isn't shown in the
language README, WebFetch the relevant entry from `shared/live-sources.md`
rather than guess. C# has beta Managed Agents support via `client.Beta.Agents`
and related namespaces — see `csharp/claude-api/README.md` for details, or
`curl/managed-agents.md` for raw HTTP reference.

**When the user wants to set up a Managed Agent from scratch** (e.g. "how do I
get started", "walk me through creating one", "set up a new agent"): read
`shared/managed-agents-onboarding.md` and run its interview — same flow as the
`managed-agents-onboard` subcommand.

**When the user asks "how do I write the client code for X":** reach for
`shared/managed-agents-client-patterns.md` — covers lossless stream reconnect,
`processed_at` queued/processed gate, interrupt, `tool_confirmation` round-trip,
the correct idle/terminated break gate, post-idle status race, stream-first
ordering, file-mount gotchas, etc. For credentials, lead with vault
`environment_variable` credentials — the first-class mechanism; secrets are
substituted at egress and never enter the sandbox
(`shared/managed-agents-tools.md` → Vaults). Keeping credentials host-side via
custom tools is the fallback where vault credentials don't fit (e.g. self-hosted
sandboxes).

**When the user wants the agent to run on a schedule** (cron, "every night",
"weekly report"): read `shared/managed-agents-scheduled-deployments.md` —
deployments fire sessions autonomously on a cron cadence, with per-firing run
records and lifecycle controls (pause/unpause/archive).

**When the agent's work fans out** (research across several sources, per-file or
per-record work, "look into N things, then summarize") **or one loop would fill
its context with reading:** read `shared/managed-agents-multiagent.md` and
recommend a multiagent session — start with just `{"type": "self"}` in the
roster so the agent can delegate to copies of itself, then move reading-heavy
sub-tasks to a cheaper worker agent (e.g. Claude Haiku 4.5) referenced by ID.

---

## Server Tools (Quick Reference)

Server-side tools run on Anthropic's infrastructure — no client-side execution
loop. Declare in `tools`; results arrive as content blocks in the same response.
**No beta header** unless noted. **Prefer the latest type variant your model
supports.** The `_20260209` web search / web fetch variants below (dynamic
filtering) require Opus 5/4.8/4.7/4.6, Sonnet 5, or Sonnet 4.6; the basic
variants for older models are listed after the table.

| Tool | `type` | `name` | Key optional params | Result block type |
|---|---|---|---|---|
| Web search | `web_search_20260209` | `web_search` | `max_uses`, `allowed_domains`/`blocked_domains`, `user_location` | `web_search_tool_result` → `.content` is a list of `web_search_result` |
| Web fetch | `web_fetch_20260209` | `web_fetch` | `max_uses`, `allowed_domains`/`blocked_domains`, `citations`, `max_content_tokens` | `web_fetch_tool_result` → `.content` is a `web_fetch_result` with a `document` block |
| Code execution | `code_execution_20260521` | `code_execution` | none | `bash_code_execution_tool_result` → `.content.stdout` / `.stderr` / `.return_code` |
| Tool search (regex) | `tool_search_tool_regex_20251119` | `tool_search_tool_regex` | mark other tools `defer_loading: true` | `tool_search_tool_result` |
| Tool search (BM25) | `tool_search_tool_bm25_20251119` | `tool_search_tool_bm25` | mark other tools `defer_loading: true` | `tool_search_tool_result` |

`web_search_20260209` / `web_fetch_20260209` have built-in dynamic filtering —
code execution runs under the hood, so do **not** separately declare
`code_execution` in `tools` (a second execution environment confuses the model).
For models older than Opus 4.6 / Sonnet 4.6, use the basic variants
`web_search_20250305` / `web_fetch_20250910` instead; on Vertex AI only basic
`web_search_20250305` is available. `code_execution_20260120` (REPL persistence
+ programmatic tool calling) runs on Opus 4.5+ / Sonnet 4.5+. **Go SDK only**:
`code_execution_20260521` lives under `client.Beta.Messages.New` with `Betas:
[]anthropic.AnthropicBeta{"code-execution-2025-08-25"}` (other languages use
plain `client.messages.create`); `code_execution_20260120` uses the non-beta
`client.Messages.New` in Go like everywhere else. Web fetch only fetches URLs
already present in the conversation. Provider availability varies by tool —
see `shared/platform-availability.md`. See `shared/tool-use-concepts.md` for
`pause_turn` handling.

## Document & File Input (Quick Reference)

**PDF (base64, no beta):** `{"type": "document", "source": {"type": "base64",
"media_type": "application/pdf", "data": <b64 string>}}` in user content, placed
before the text block. Base64 string must have no newlines. Limits: 32 MB
request, 600 pages (100 for 200k-context models). Java:
`ContentBlockParam.ofDocument(DocumentBlockParam...
Base64PdfSource.builder().data(...))`.

**Files API (beta `files-api-2025-04-14`):** upload via
`client.beta.files.upload(...)` → response `id` is the `file_id`. Reference it
as `{"type": "document", "source": {"type": "file", "file_id": "..."}}` for
PDF/text, or `{"type": "image", ...}` for images — the content-block type must
match the file's MIME type. The beta header is required on **both** the upload
and the `messages.create` that references the file. Availability:
`shared/platform-availability.md`.

**Citations (no beta):** set `citations: {enabled: true}` on each `document`
content block (all or none). Response splits into multiple `text` blocks; cited
blocks carry a `citations` array. Each citation has `cited_text`,
`document_index`, `document_title`, and a location by `type`: `char_location`
(`start_char_index`/`end_char_index`) for plain text, `page_location`
(`start_page_number`/`end_page_number`, 1-indexed) for PDF,
`content_block_location` for custom content. Incompatible with
`output_config.format` (returns a 400).

## Tool Use Patterns (Quick Reference)

**Strict tool use (no beta):** set `strict: true` as a top-level field on the
tool definition (alongside `name`/`description`/`input_schema`), **not** on
`tool_choice`. Schema must have `additionalProperties: false` + `required`.
Guarantees `tool_use.input` validates exactly. Go: `Strict:
anthropic.Bool(true)` + `additionalProperties` via `InputSchema.ExtraFields`;
Java: `.strict(true)` + `.putAdditionalProperty("additionalProperties",
JsonValue.from(false))`.

**Parallel tool use (default on):** one assistant message may contain multiple
`tool_use` blocks. Execute them concurrently, then return **all** `tool_result`
blocks in a **single** user message — splitting them across multiple messages
silently trains Claude to stop making parallel calls. For a failed tool, return
`tool_result` with `is_error: true` — don't drop it.

**Tool Runner (SDK beta helper):** drives the tool-call loop for you via
`client.beta.messages.*`. Python: `@beta_tool` decorator +
`client.beta.messages.tool_runner(...)` → `runner.until_done()`. TypeScript:
`betaZodTool({...})` from `@anthropic-ai/sdk/helpers/beta/zod` +
`client.beta.messages.toolRunner(...)` → `await runner`. Go:
`toolrunner.NewBetaToolFromJSONSchema(...)` +
`client.Beta.Messages.NewToolRunner(...)` → `.RunToCompletion(ctx)`. Java
requires `.addBeta("structured-outputs-2025-11-13")`. Ruby:
`Anthropic::BaseTool` subclass + `client.beta.messages.tool_runner(...)`. PHP:
`BetaRunnableTool` + `->toolRunner(...)`. C#: raw JSON-schema tools +
`BetaToolRunner` via `client.Beta.Messages.ToolRunner(...)`.

**Programmatic tool calling (no beta header):** Claude calls your custom tool
from inside code execution. Add `{"type": "code_execution_20260120", "name":
"code_execution"}` **and** set `"allowed_callers": ["code_execution_20260120"]`
on your custom tool. Opus 4.5+ / Sonnet 4.5+ (availability:
`shared/platform-availability.md`). When responding to a pending programmatic
call, the user message must contain **only** `tool_result` blocks (no text). Not
compatible with `strict: true`, `disable_parallel_tool_use`, forced
`tool_choice`, or MCP tools.

## Other API Surfaces (Quick Reference)

**Message Batches (no beta; availability: `shared/platform-availability.md`):**
`client.messages.batches.create(requests=[{custom_id, params}, ...])` → poll
`client.messages.batches.retrieve(id).processing_status` until `"ended"` →
stream `client.messages.batches.results(id)`. Each result has `.custom_id` +
`.result.type` (`succeeded`/`errored`/`canceled`/`expired`); on success read
`.result.message.content`. Python wraps requests as `Request(custom_id=...,
params=MessageCreateParamsNonStreaming(...))`. Results arrive in **any order**
— key by `custom_id`, never by position.

**Models API (no beta; availability: `shared/platform-availability.md`):**
`client.models.list()` (auto-paginates) and
`client.models.retrieve("claude-opus-5")`. Each model object has `id`,
`display_name`, `created_at`, and — since Mar 2026 — `max_input_tokens` (the
context window), `max_tokens` (the output cap), and `capabilities`. There is no
`context_window` field.

**Stop details (GA, Opus 4.7+):** `response.stop_details` is populated **only
when `stop_reason == "refusal"`** (fields: `type: "refusal"`, `category` — an
open set, e.g. `"cyber"`, `"bio"`, `"reasoning_extraction"`, `"frontier_llm"`,
or `null`; see the docs for the full list — and `explanation`). It is `null`
for every other `stop_reason` (`end_turn`, `max_tokens`, `tool_use`,
`pause_turn`, …) — always guard before reading.

**Client config (no beta):** `timeout` default 10 min; **units differ by SDK**
— Python/Ruby: seconds; TypeScript: **milliseconds**; Go
`option.WithRequestTimeout(time.Duration)`; Java `Duration`; C# `TimeSpan`. TS
scales the default up to 60 min for large `max_tokens` on non-streaming
requests; Java does so for streaming requests (Java non-streaming scales
30s–10 min). `max_retries`/`maxRetries` default 2 (retries 408/409/429/5xx +
connection errors). `base_url` (or `ANTHROPIC_BASE_URL` env). Per-request
override: Python `client.with_options(timeout=5.0).messages.create(...)`; TS
`client.messages.create({...}, {timeout: 5_000})`; Ruby `request_options:
{timeout: 5}`. Timeouts are retried — wall-clock can reach `timeout ×
(max_retries+1)`.

## Workload Identity Federation (Quick Reference)

**GA, no beta header.** Construct the normal zero-arg client (`Anthropic()` /
`new Anthropic()` / `anthropic.NewClient()` /
`AnthropicOkHttpClient.fromEnv()`); the SDK auto-detects WIF when **all** of
`ANTHROPIC_FEDERATION_RULE_ID`, `ANTHROPIC_ORGANIZATION_ID`,
`ANTHROPIC_SERVICE_ACCOUNT_ID`, and `ANTHROPIC_IDENTITY_TOKEN_FILE` (or
`ANTHROPIC_IDENTITY_TOKEN`) are set, exchanges the JWT at `/v1/oauth/token`, and
auto-refreshes. `ANTHROPIC_WORKSPACE_ID` does not gate activation — required
only when the federation rule spans multiple workspaces (else 400
`workspace_id_required`), optional for single-workspace rules.
`ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` (even empty) outrank WIF, and a
set `ANTHROPIC_PROFILE` also wins over the federation env vars (a missing named
profile is an error, not a fall-through) — unset all three.

---

## Reading Guide

After detecting the language, read the relevant files based on what the user
needs. Every `{lang}/…`, `shared/…`, and `curl/…` path cited in this
document is relative to this skill's base directory, and none of those files'
content is included above — Read each one on demand before relying on what it
covers.

**All SDK languages use the same multi-file layout** — directory
`{lang}/claude-api/` containing `README.md` (install, client init, basic
request, thinking, caching, stop details, misc), `tool-use.md` (tool
definitions, agentic loop, Anthropic-defined tools, structured outputs),
`streaming.md`, `batches.md`, `files-api.md`. Not every language has every file
(e.g., Ruby has no `batches.md`); if a file is absent, that feature's example is
not yet documented for that language — fall back to the cURL shape or WebFetch
the SDK repo from `shared/live-sources.md`. **cURL** → `curl/examples.md`.

The Quick Task Reference below uses the `{lang}/claude-api/FILE.md` path
notation for all languages.

## Quick Task Reference

**Single text classification/summarization/extraction/Q&A:**
→ Read only `{lang}/claude-api/README.md` — **always read the README first**
for any task (installation, quick start, common patterns, error handling)

**Chat UI or real-time response display:**
→ Read `{lang}/claude-api/README.md` + `{lang}/claude-api/streaming.md`

**Long-running conversations (may exceed context window):**
→ Read `{lang}/claude-api/README.md` — see Compaction section
**Migrating to a newer model (Fable 5 / Opus 5 / Opus 4.8 / Opus 4.7 / Opus 4.6
/ Sonnet 5 / Sonnet 4.6), replacing a retired model, or translating
`budget_tokens` / prefill patterns to the current API:**
→ Read `shared/model-migration.md`
**Upgrading the Anthropic SDK package itself across a major version (`anthropic`
0.x → 1.x: `httpx2`, awaited async `.with_raw_response`, removed deprecated
parameters / aliases / Text Completions, Python ≥ 3.10) — or writing new
code against a project already on 1.x:**
→ Read `{lang}/claude-api/sdk-upgrade.md` (currently Python only; other SDKs
have no bundled major-version guide yet — use that SDK's CHANGELOG via
`shared/live-sources.md`)
**Prompting or tuning Fable 5 (long turns, effort, verbosity, autonomous runs,
sub-agents):**
→ Read `shared/model-migration.md` → Migrating to Fable 5 → Behavioral
shifts (prompt-tunable) + Long-running agent recommendations
**Prompt caching / optimize caching / "why is my cache hit rate low":**
→ Read `shared/prompt-caching.md` (prefix-stability design, breakpoint
placement, anti-patterns that silently invalidate cache) +
`{lang}/claude-api/README.md` (Prompt Caching section)
**Auditing or cleaning up prompts, skills, or tool descriptions ("is this prompt
outdated", "remove the cruft", "this was written for an older model"):**
→ Read `shared/prompt-audit.md` — dated-pattern tables with greppable
signals, the keep list (what NOT to delete), and the report + proposed-diff
output contract
**Count tokens in a file / prompt / diff ("how many tokens is X"):**
→ Read `shared/token-counting.md` — use `messages.count_tokens`, never
`tiktoken`

**Function calling / tool use / agents:**
→ Read `{lang}/claude-api/README.md` + `shared/tool-use-concepts.md`
(conceptual foundations: function calling, code execution, memory, structured
outputs) + `{lang}/claude-api/tool-use.md` (language-specific code examples:
tool runner, manual loop, code execution, memory, structured outputs)

**Agent design (tool surface, context management, caching strategy):**
→ Read `shared/agent-design.md` (bash vs. dedicated tools, programmatic tool
calling, tool search/skills, context editing vs. compaction vs. memory, caching
principles)

**Batch processing (non-latency-sensitive; runs asynchronously at 50% cost):**
→ Read `{lang}/claude-api/README.md` + `{lang}/claude-api/batches.md`

**File uploads across multiple requests (same file without re-uploading):**
→ Read `{lang}/claude-api/README.md` + `{lang}/claude-api/files-api.md`

**Debugging HTTP errors or implementing error handling:**
→ Read `shared/error-codes.md` — per-SDK typed exception class table and the
Go `errors.As` pattern

**Latest official documentation:**
→ WebFetch the URLs in `shared/live-sources.md`

**Managed Agents (server-managed stateful agents with workspace):**
→ See the reading guide in the `## Managed Agents (Beta)` section above — it
lists every `shared/managed-agents-*.md` file and the language-specific READMEs
(`{lang}/managed-agents/README.md`, `curl/managed-agents.md`).

---

## When to Use WebFetch

Use WebFetch to get the latest documentation when:

- User asks for "latest" or "current" information
- Cached data seems incorrect
- User asks about features not covered here

Live documentation URLs are in `shared/live-sources.md`.

## Common Pitfalls

- Don't truncate inputs when passing files or content to the API. If the content
  is too long to fit in the context window, notify the user and discuss options
  (chunking, summarization, etc.) rather than silently truncating.
- **Prefill removed (Fable 5, Opus 5, Sonnet 5, and the 4.6/4.7/4.8 family):**
  Assistant message prefills (last-assistant-turn prefills) return a 400 error
  on Fable 5, Opus 5, Sonnet 5, Opus 4.6, Opus 4.7, Opus 4.8, and Sonnet 4.6.
  Use structured outputs (`output_config.format`) or system prompt instructions
  to control response format instead. (One exception: the fallback-credit
  prefill claim — when redeeming a credit with `fallback_has_prefill_claim:
  true`, the server accepts the echoed assistant message; see the migration
  guide's refusal section.)
- **Confirm migration scope before editing:** When a user asks to migrate code
  to a newer Claude model without naming a specific file, directory, or file
  list, **ask which scope to apply first** — the entire working directory, a
  specific subdirectory, or a specific set of files. Do not start editing until
  the user confirms. Imperative phrasings like "migrate my codebase", "move my
  project to X", "upgrade to Sonnet 4.6", or bare "migrate to Opus 4.8" are
  **still ambiguous** — they tell you what to do but not where, so ask.
  Proceed without asking only when the prompt names an exact file, a specific
  directory, or an explicit file list ("migrate `app.py`", "migrate everything
  under `services/`", "update `a.py` and `b.py`"). See
  `shared/model-migration.md` Step 0.
- **`max_tokens` defaults:** Don't lowball `max_tokens` — hitting the cap
  truncates output mid-thought and requires a retry. For non-streaming requests,
  default to `~16000` (keeps responses under SDK HTTP timeouts). For streaming
  requests, default to `~64000` (timeouts aren't a concern, so give the model
  room). Only go lower when you have a hard reason: classification (`~256`),
  cost caps, deliberately short outputs, or **`max_tokens: 0`** for cache
  pre-warming (see `shared/prompt-caching.md` → Pre-warming).
- **Disabling thinking on Claude Opus 5 has two failure modes — prefer
  low/medium effort instead.** Only affects code that explicitly opts out;
  thinking is on by default, so watch for a disabled-thinking setting carried
  forward from Opus 4.8. With `thinking: {type: "disabled"}`, the model
  occasionally writes a tool call into its **visible text** instead of a
  `tool_use` block: the turn succeeds, the call never runs, no error is raised,
  and in an agentic loop that text pollutes later turns. It can also leak
  `<thinking>` tags into the response. Turning thinking on and lowering `effort`
  fixes both and still cuts cost. If a route must stay thinking-off: add *"You
  may say a brief sentence before using a tool"*, **delete** any
  don't-think/don't-reason rule (it makes tag leakage worse), and use a generic
  *"Do not include internal or system XML tags in your response"* rather than
  naming thinking tags. Details: `shared/model-migration.md` → Two failure
  modes when thinking is disabled.
- **128K output tokens:** Fable 5, Opus 5, Opus 4.6, Opus 4.7, Opus 4.8, Sonnet
  5, and Sonnet 4.6 support up to 128K `max_tokens`, but the SDKs require
  streaming for values that large to avoid HTTP timeouts. Use `.stream()` with
  `.get_final_message()` / `.finalMessage()`.
- **Tool call JSON parsing (Fable 5, Opus 5, and the 4.6/4.7/4.8 family):**
  Fable 5, Opus 5, Opus 4.6, Opus 4.7, Opus 4.8, and Sonnet 4.6 may produce
  different JSON string escaping in tool call `input` fields (e.g., Unicode or
  forward-slash escaping). Always parse tool inputs with `json.loads()` /
  `JSON.parse()` — never do raw string matching on the serialized input.
- **Structured outputs (all models):** Use `output_config: {format: {...}}`
  instead of the deprecated `output_format` parameter on `messages.create()`.
  This is a general API change, not 4.6-specific.
- **Don't reimplement SDK functionality:** The SDK provides high-level helpers
  — use them instead of building from scratch. Specifically: use
  `stream.finalMessage()` instead of wrapping `.on()` events in `new Promise()`;
  use typed exception classes (`Anthropic.RateLimitError`, etc.) instead of
  string-matching error messages; use SDK types (`Anthropic.MessageParam`,
  `Anthropic.Tool`, `Anthropic.Message`, etc.) instead of redefining equivalent
  interfaces.
- **Error handling — catch a chain, not one broad class.** A single `except
  APIStatusError` / `catch (AnthropicServiceException)` / `rescue APIError`
  loses the distinction between retryable (429, ≥500, network) and
  non-retryable (400/404) failures. Write a most-specific-first chain — e.g.
  `NotFoundError` → `RateLimitError` → `APIStatusError` →
  `APIConnectionError` (or the Go equivalent: `errors.As` into
  `*anthropic.Error` then `switch apierr.StatusCode { case 404: …; case 429:
  …; default: … }`). Per-language class names and namespaces are in
  `shared/error-codes.md`.
- **Don't research SDK types — write first.** If a type name isn't shown in
  the documentation included in this skill, write the code file from the
  namespace/package tables in the language-specific doc and let the compiler's
  error point you to the right name. Do not spend turns on WebFetch, SDK-repo
  clones, or compiling-and-running a separate reflection program to discover
  type names before writing — produce the source file first, then fix what the
  compiler reports. A quick `strings` / `jar tf` / `javap` against the installed
  SDK is acceptable for locating names (it returns in seconds), but don't
  escalate beyond that. A file with a wrong type name is recoverable; a session
  spent on discovery with no file written is not.
- **Bash and text editor tools are Anthropic-defined, schema-less.** Declare
  `{"type": "bash_20250124", "name": "bash"}` / `{"type":
  "text_editor_20250728", "name": "str_replace_based_edit_tool"}` — no
  `input_schema`. A custom tool with your own schema named `"bash"` is a
  different tool. Handler paths and security checks are in
  `shared/tool-use-concepts.md` § Client-Side Tools.
- **Advisor tool model pairing.** The advisor tool's `model` must be at least as
  capable as the request's top-level `model` — e.g. executor `claude-sonnet-5`
  → advisor `claude-opus-4-8` or `claude-opus-4-7`. An invalid pair returns
  400. Pairing table in `shared/tool-use-concepts.md` § Advisor. Availability:
  `shared/platform-availability.md`.
- **Agent Skills ≠ Managed Agents.** To have Claude generate a
  `.pptx`/`.xlsx`/etc. via Agent Skills, call `client.beta.messages.create` with
  `container={"skills": [...]}`, the `code_execution_20260521` tool, and both
  `code-execution-2025-08-25` + `skills-2025-10-02` betas. Do not use
  `client.beta.agents` / `sessions` / `environments` here — those are the
  Managed Agents surface, not Agent Skills.
- **MCP connector needs both halves.** `mcp_servers=[{type:"url", url, name}]`
  alone is rejected as a validation error — also add
  `tools=[{type:"mcp_toolset", mcp_server_name:<same name>}]` with beta
  `mcp-client-2025-11-20`. Availability: `shared/platform-availability.md`.
- **`inference_geo` is a direct top-level request parameter** —
  `client.messages.create(..., inference_geo="us")` / `.inferenceGeo("us")`. Do
  not put it in `extra_body` / `putAdditionalBodyProperty`. (Messages API only
  — on Managed Agents, `inference_geo` instead nests inside the agent's
  `model` object, never top-level; see `shared/managed-agents-core.md` §
  Pinning inference geography.) Supported on Opus 4.6 / Sonnet 4.6 and later;
  availability: `shared/platform-availability.md`.
  `response.usage.inference_geo` reports where inference ran.
- **Fine-grained tool streaming is not a beta feature.** Set
  `eager_input_streaming: true` on the tool definition and call the regular
  `client.messages.stream(...)`. There is no beta header and no `client.beta.*`
  path.
- **Cache diagnostics is beta.** Use `client.beta.messages.*` with beta
  `cache-diagnosis-2026-04-07`. Pass `diagnostics: {previous_message_id: null}`
  on the first turn and `diagnostics: {previous_message_id: <previous response
  id>}` on subsequent turns; the result is on `response.diagnostics`.
  Availability: `shared/platform-availability.md`.
- **Memory tool type is `memory_20250818`.** Declare `{"type":
  "memory_20250818", "name": "memory"}`. Go uses the beta-namespace type
  `{OfMemoryTool20250818: &anthropic.BetaMemoryTool20250818Param{}}` on
  `client.Beta.Messages.New`; Python/TypeScript/Ruby/PHP/C# use the non-beta
  `client.messages.create`; Java has both a non-beta `MemoryTool20250818` and a
  beta tool-runner path. Python/TypeScript provide `BetaAbstractMemoryTool` /
  `betaMemoryTool` helpers for implementing the backend.
- **Use a model the feature actually supports.** Some features are restricted to
  specific model tiers — fast mode is Claude Opus 5 / Opus 4.8 only (and
  Claude API only), task budgets (Messages API only — Managed Agents session
  budgets have no model-tier restriction) are Claude Opus 5 / Fable 5 / Sonnet 5
  / Opus 4.8 / 4.7 only, and the advisor tool requires a valid
  executor↔advisor pair. If the user's prompt names a model that the feature
  doesn't support, use a supported model instead and note the substitution in
  the output.
- **Don't define custom types for SDK data structures:** The SDK exports types
  for all API objects. Use `Anthropic.MessageParam` for messages,
  `Anthropic.Tool` for tool definitions, `Anthropic.ToolUseBlock` /
  `Anthropic.ToolResultBlockParam` for tool results, `Anthropic.Message` for
  responses. Defining your own `interface ChatMessage { role: string; content:
  unknown }` duplicates what the SDK already provides and loses type safety.
- **Report and document output:** For tasks that produce reports, documents, or
  visualizations, the code execution sandbox has `python-docx`, `python-pptx`,
  `matplotlib`, `pillow`, and `pypdf` pre-installed. Claude can generate
  formatted files (DOCX, PDF, charts) and return them via the Files API —
  consider this for "report" or "document" type requests instead of plain stdout
  text.
- **Server-tool errors don't raise.** Web search and web fetch errors return
  HTTP 200 with a `web_search_tool_result` / `web_fetch_tool_result` block whose
  `content` is a single error object (e.g. `{error_code: "max_uses_exceeded"}`)
  — not a raised exception. For web search, a success `content` is a *list*;
  an error `content` is an *object* — branch on that before indexing.
- **Managed Agents web tools ignore the environment's `networking`.**
  `web_search` / `web_fetch` run on Anthropic's servers in cloud *and*
  self-hosted environments, and Console org-level web settings apply to the
  Messages API only. Restrict them per tool with `allowed_domains` **or**
  `blocked_domains` (never both; 1–64 plain hostnames per list, subdomains
  covered; IPs, bare TLDs, single-label and `localhost`-style names rejected on
  both tools; a path suffix is allowed only on `web_search`) on the toolset
  `configs` entry — `shared/managed-agents-tools.md` § Web search & web fetch
  settings.
- **Code execution output block type:** `code_execution_20260521` returns
  `bash_code_execution_tool_result` (with `.content.stdout`), **not** the legacy
  bare `code_execution_tool_result`. Iterate `response.content` and match on the
  correct type.
- **Tool search: never defer everything.** The search tool itself must not have
  `defer_loading: true`, and at least one tool in `tools` must be non-deferred,
  or the API returns 400 `All tools have defer_loading set`.

No project language was auto-detected. Ask the user which language they are
using (see Language Detection above), then Read the matching
`{lang}/claude-api/README.md` (or `curl/examples.md` for cURL/raw HTTP or an
unsupported language) from the base directory before anything else.

## User Request

designing an in-game AI assistant with tool calls, gated by a human approver;
deciding local model vs hosted API

--------------------------------------------------------------------------------

### Assistant Response 6

> Now the documents. The doc band (001–019) is full — source starts at 020
> — so these take the next counter values and I'll flag the numbering for the
> refactor.

> The link checker caught six stale references from before I settled the
> numbering. Fixing:

> Written up. Here's what landed:
>
> **Nine issue files** in `issues/` — the edge graph, structures and
> elevation, visibility as one equation, the distance field, the unseen as a
> surface, the pass sequence, the third view, the question window, and the
> capstone demo.
>
> **Three documents** — `109-the-world-is-an-edge-graph`,
> `110-visibility-is-one-equation`, `111-the-question-window`. They say what
> they supersede rather than quietly disagreeing with docs 006, 007 and 012.
>
> **Seven open questions**, 17.1 through 17.7, and question 2.1 rewritten to
> record that it died twice and where its remainder went. 17.7 is recorded as
> *dissolved* — the ambush needed no new structure — because your notes say
> a question that dies is worth keeping with the reasoning that killed it.
>
> **A phase 13 progress file** holding what the design taught before anything
> was built, and **the roadmap and table of contents updated**. The link checker
> reports nothing broken; the docs site rebuilt to 317 pages, up from 287, every
> reference resolving.
>
> Two things I want to flag from doing it. The link mender caught six dead
> references I had written — I numbered the docs 020/021/022 before realising
> the document band is full, since source starts at 020. So they took 109, 110,
> 111 from the counter, which is the counter's rule working exactly as written
> and producing an answer nobody wants. That's now noted in the table of
> contents as the thing the renumber has to fix.
>
> And the phases table in the table of contents had never had phase 12 added. It
> stopped at 11. Now it has both.
>
> ---
>
> ## Slimming thirteen to six
>
> Grouping by what a phase is *about* rather than by what got built first:
>
> | New | Folds in | Cluster |
> | --- | --- | --- |
> | **1. The world** | 1, and 13's edge graph, structures, elevation | What a world is and how it is held. Fixed point, flat arrays, the validator, snapshot, and now vertices, edges, materials, and the ground. All of it is the format. |
> | **2. Time** | 3, and 13's pass sequence | The tick, the passes, motion, determinism, the command log, replay, the turn as a transaction, the undo, and the schedule. |
> | **3. Seeing** | 2, and 13's visibility and distance field | Sight, fog, reveal, thresholds, the gradient, and what a viewer is allowed to know. The whole arc from raycasting to authoring lives in one place. |
> | **4. People** | 4, 6, 12 | The door, the ports, the protocol, the filter, scopes, control as a dial, multiple GMs, eviction, unwind, and a squad on one keyboard. Everything about who may do what. |
> | **5. Rules and content** | 7, 8, and the question window | LuaJIT, hooks, sheets, the description language, generation — and the AI, which belongs here because its tool surface is the DM's verbs and its ignorance is arithmetic. |
> | **6. Views, and what survives** | 5, 9, 10, 11, and 13's third view and portal impostor | The bridge, the browser, the terminal, the 3D view, the sprite studio, the engraving, and the documentation site. Everything that turns state into something a person looks at. |
>
> That mapping has a property worth checking against your rule that lower
> numbers should be more foundational: it holds. The world is read before time,
> time before seeing, seeing before people, and the views last, which is also
> the dependency order.
>
> **Three costs, and one of them is real.**
>
> The small one: phases 9 and 10 currently *are* their own thing, and folding
> the sprite studio and the engraving into "views and what survives" is the
> coarsest join in the table. They fit, but less snugly than the others.
>
> The medium one: this renumbers 105 issue files and 163 source files. The link
> mender exists for exactly that, and just proved it works. It needs two commits
> so git tracks both the before and the after.
>
> The real one: **there are twelve demos and there would be six phases.** A
> phase ending in a demo is a rule this project has kept twelve times, and the
> demos are described as part of what it delivers rather than as scrap. Merging
> twelve into six loses the granularity that lets somebody run *just* the
> determinism one. Keeping twelve across six phases breaks the
> one-demo-per-phase rule. I do not think there is a third option, and I think
> it is your call rather than mine.

> **[Asked the user]**
>
> *Q1 — Slim scope:* How far should the slim go?
> - Full renumber — phases, issues, source, docs (Recommended) — Six phases,
>   and every file renumbered so the numbers mean reading order again. 105 issue
>   files, 163 source files, the three misplaced documents pulled back into the
>   low band, every link repointed by the mender. Two commits so git holds both
>   versions. Expensive once, and afterwards the numbering convention is telling
>   the truth instead of being explained away in a note.
> - Regroup the phases only, leave every number alone — The roadmap gets six
>   sections; issue and source files keep the numbers they have. Cheap,
>   reversible, and nothing can break. The cost is that a file numbered 1204
>   would live in phase four, so the number stops naming the phase — which is
>   the whole convention, and the table of contents would need a longer note
>   than the one it already has.
> - Slim the writing first, renumber later — Run the documentation refactor
>   over what exists — strip comments a fluent reader could infer, collapse
>   facts stated in three files down to one home plus a link, cut worklog
>   residue out of issue files — and see how much is left before deciding the
>   shape. It may be that thirteen phases of prose slims to six phases' worth
>   without moving a single file.
> → **Answered:** eh let's just do the re-organization later
>
> *Q2 — Demos:* What happens to the twelve demos?
> - Keep all twelve, drop the one-per-phase rule — Six phases, twelve demos,
>   and run-phase-demo keeps offering all of them by name. The rule becomes 'a
>   phase ends with at least one demo'. Nothing is lost and nothing is rewritten
>   — you can still run just the determinism one.
> - Merge into six, one per phase — Each new phase gets one demo that
>   recombines what its folded-in phases showed. Keeps the rule exactly, and the
>   merged demos would be genuinely bigger and more impressive as a deliverable.
>   The cost is twelve working programs rewritten into six, and losing the
>   ability to run one narrow thing.
> - Keep twelve, and add six overview demos on top — The twelve stay as they
>   are, and each new phase gets a short demo that ties its cluster together.
>   Most work of the three, most complete result — you can run the narrow one
>   or the wide one. Eighteen programs to keep working forever, which is the
>   part that gets expensive later rather than now.
> → **Answered:** one demo per phase that highlights the behavior learned in
> that phase

> Reorganization deferred, then. Let me record the demo rule and the deferral so
> neither gets lost.

Committed as `b64c98a0` — 18 files, 1,308 lines added.

**What I left out of the commit:** `llm-transcripts/` is untracked in this
project and it isn't mine — it was already there when this session started.
Every other project of yours tracks its transcripts, so I suspect it should be
committed, but I'd rather ask than stage somebody else's work. Want it in?

**What I recorded from your two answers.** The demo rule is now written into the
roadmap as *one demo per phase, and it highlights the behaviour that phase
learned* — with the reason attached, that a demo listing what got built is a
changelog with a compiler, and the finding is the part that survives when the
phases are eventually regrouped while the file list is not. And the six-phase
regrouping is in `desire/what-would-be-better` as deferred on purpose rather
than forgotten, with the mapping and the reason for waiting: the right moment is
after the writing is slimmed, not while a phase is still being designed. The
table of contents note about the numbering now points at that wish instead of
insisting the renumber happen.

**Where phase thirteen actually stands.** Designed, not built, and by your own
rule it is *in progress* rather than delivered, because seven open questions
came out of the design and none are answered. Two of them block building rather
than polishing:

**17.1 — who issues the notice that ends "static"?** A thing keeps its cached
visibility terms until further notice, and nothing issues the notice. A DM drags
a vertex under a static crate and the crate has no idea its cached terms went
stale. This is the entire difficulty of the caching scheme and it stays
invisible until the session where a room lights up and somebody standing in it
cannot see. Two shapes are available and I wrote both down: a generation counter
per structure, which catches everything and costs a comparison per lookup, or
explicit invalidation at each edit site, which is free at read time and relies
on nobody ever adding a tenth edit site and forgetting.

**17.4 — what does a beat mean once the passes are a sequence?** Two motions
in a row move a body twice on one intent. That is coherent for both kinds of
order, but a beat stops meaning a fixed amount of movement, and everything
converting beats to metres has to learn it. The real decision underneath is
whether intent should be cleared *when it is consumed* rather than at the start
of a beat — the start-of-beat clear was chosen so a cancelled order could
never leave a body walking, and under a schedule that same clear is what would
delete an intent the second motion was about to use.

The other five are 17.2 (is mind a flag or a measurement), 17.3 (where the
terrain grid's cell size comes from — 2.1's third life), 17.5 (which AI,
running where), 17.6 (is keeping the ray caster a real decision or a way of not
deciding), and 17.7, which is already answered because it dissolved.

Which would you like to take next?

--------------------------------------------------------------------------------

