# SoraMech Notes — patterns found while building the spellcraft engine

> **What this file is.** First Person Spellcraft is built on a SoraMech-style
> dataflow substrate — boxes that fire when their inputs are ready, values
> flowing through per-port ring buffers, a long-running circular map that never
> quiesces. Building a *game* on that substrate stresses it in ways a batch
> LLM pipeline never does (a 60 Hz heartbeat, a delta-input device, a real-time
> render consumer). Each stress teaches a pattern. This file records those
> patterns so that when SoraMech itself is refactored, the lessons learned
> downstream are available upstream.
>
> This file is the canonical copy. A shared copy lives in the SoraMech project
> (see "Sharing" at the bottom); commit both when this changes.

Ordered most-load-bearing first.

---

## 1. Long-running circular maps are the *primary* shape, not a footnote

A game never runs dry. It re-fires its whole graph ~60 times a second until a
quit signal. This is not an exotic use of a dataflow runtime — it is the normal
one, and a batch pipeline that drains to quiescence is the *special* case.

**Mechanism.** A box fires whenever its inputs arrive, so wiring the graph to
feed itself closes a loop that turns forever. The loop must be built from
cycle-safe constructs — an iterator-routing box, or a re-arming heartbeat — not
a raw back-edge, which the loader rejects as a deadlock risk.

**SoraMech implication.** Already reflected upstream (docs clarified: quiescence
is the batch fate; circular is primary). The game is the proof case.

---

## 2. Two-tier value transport: consume-every-event vs. latest-wins

Not every hand-off wants a queue. There are two disciplines, and conflating
them causes either lost motion or pointless buffering.

- **Consume-every-event (a FIFO ring).** Between compute boxes where every
  value counts — an LLM pipeline stage, or mouse deltas that must all be
  integrated. The consumer drains the ring.
- **Latest-wins (a single overwritable cell, peeked not popped).** Into a
  *constant consumer* that only ever wants "the current value" — the renderer
  reading an object's present position. History is noise; overwriting is
  correct; there is nothing to drain and nothing to zero.

**SoraMech implication.** SoraMech already has both underneath — a FIFO ring
slot and a 1-cell peek slot (`slot_peek`, doesn't advance head). Worth
promoting "latest-wins overwrite" to a *named* slot flavor with its own flag,
because it's a first-class transport discipline, not a degenerate ring.

---

## 3. Drain-and-sum for delta devices

A mouse reports *relative* motion ("+4, -2"), not position. Between two frames a
handful of deltas pile up. Taking only the newest loses motion; you must pop
*all* of them and add them together.

**Mechanism.** The reader is a multi-spawn drainer: each tick it pops every
queued delta and integrates them into one frame-delta. Ring size 3–5 cells is
plenty — enough to survive a burst between frames without unbounded buffering.

**SoraMech implication.** Maps onto iterator / multi-spawn re-fire (a box that
keeps firing while its POP inputs have values to drain). The delta-integrator is
a clean, tiny worked example of that routing.

---

## 4. Build-off-to-side, then publish with the single last write

The anti-tearing rule for handing a multi-field record to a consumer that may
read it concurrently: never let the consumer see a half-written record.

**Mechanism.** Treat it exactly like a box and its arguments — first define the
record's structure and location, then populate it fully off to the side, then
hand the *ownership pointer* to the ring buffer as the single, final write. The
consumer either sees the old whole value or the new whole value, never a mix.
The pointer hand-off is the atomic publish, the same way a pointer swap
double-buffers a frame. The producer must not mutate the record after publishing
it (immutable-once-published).

**SoraMech implication.** Maps onto the large-value-heap chunk handle — push
acquires a chunk (refcount 1, owned by the slot); the cell holds only the
handle. The "ownership transfers on push" contract is exactly this pattern and
should be stated as the anti-tearing guarantee, not just an allocator detail.

---

## 5. Sorted view over an unsorted arena, resorted by double-buffer (NEW — not in SoraMech)

A collection objects are inserted into as they move, read by a consumer that
walks it in sorted order (front-to-back, for rendering). Goal: insert without
ever shifting existing records — both for O(1) inserts and because a record that
never moves can never be torn out from under a consumer holding it.

**Mechanism (resolved design).** The store is an **unsorted append-only arena**:
a new record lands at the next free slot (O(1)), and existing records never move.
Sort order does not live in the physical layout — it lives in a separate **link
array**, where each element holds the index of the *next* element in sorted
order: a singly-linked list threaded through the arena. Inserting is a
linked-list splice — append the record, point the predecessor's link at it,
point its link at the old successor. No shift, ever. Occasionally the list is
walked in order and a **fresh compact sorted array is built off to the side and
swapped in** (double-buffer), reclaiming freed slots and restoring cache-friendly
contiguous iteration.

**Why this beats the earlier bucket idea.** An earlier draft kept `value[]`
physically sorted with a per-slot count that "rounded" neighbors into buckets to
dodge the shift. It didn't actually dodge it — the byte still had to land in the
dense array and the tail still moved. Decoupling physical position from sort
position (arena + link array) removes the shift outright.

**The publish rule still holds.** The consumer reads sorted order either by
following links (always current, pointer-chasing) or by reading the last
compacted buffer (cache-friendly, at most one compaction stale). The compaction
swap is the single publishing write, and — as in pattern 4 — the new buffer is
built fully before the consumer is pointed at it.

**SoraMech implication.** New to SoraMech. If a "sorted collection slot" is ever
wanted upstream, this arena + linked-order + double-buffer-compaction is the
reference design: stable addresses, O(1) shift-free insert, atomic publish on
compaction.

---

## 6. The frame-clock is a re-arming heartbeat box

The game's 60 Hz tick is not special engine machinery bolted beside the graph —
it is a box *inside* the graph that fires, pushes a tick, and schedules its own
next fire. That tick is what drives read-mice → solve-pose → update-renderables
each frame and keeps the map from ever quiescing.

**SoraMech implication.** This *is* the timer box (SoraMech issue 251), which is
still a design draft upstream. The game needs it for real, so our
implementation becomes a working reference for 251 — including the load-bearing
open question there (how to wait for the next tick without spinning, without
locking a worker in a sleep, without a dedicated timer thread).

---

## 7. A constant consumer can live *outside* the graph

The renderer is not a box. It is a real-time thread (raylib) that polls a
latest-wins blackboard the graph feeds, and it never blocks on the graph's
quiescence or scheduling. The dataflow map updates the blackboard; the consumer
sweeps it at its own cadence.

**Mechanism.** Boxes stamp each renderable's current state into its cell
(pattern 2, latest-wins). The render thread walks a *culled* list (only what's
on-screen, via the sorted index of pattern 5) and draws. Gamestate churns at the
graph's rate; the renderable snapshot refreshes on camera move; the two are
decoupled.

**The consumer is a self-re-arming FIFO iterator.** The pass that rebuilds the
culled renderables is expressed as an iterator box that **re-adds itself to the
pool when it finishes**, with **only ever one copy in flight** (single-spawn) and
**FIFO re-queue** so it cycles fairly instead of starving other work. This is the
same shape as the frame-clock heartbeat (pattern 6): a task whose own completion
schedules its next run, turning forever until a quit signal.

**Caveat — GL affinity forces one dedicated render thread.** The raylib draw call
can *not* ride a pool worker: a GL context is bound to the one thread that
created the window, so a task hopping pool workers can't issue GL calls. Rather
than pin a box to a chosen worker (extra pool machinery), keep it dead simple:
the **draw** lives on its own **dedicated, always-unblocked render thread** that
owns GL and runs as fast as it can, reading renderables from the graph through a
**FIFO queue slot** with a *non-blocking* pop — if nothing new is there, it
redraws the current state. It's allowed to lag the pool by a task or two; that
staleness is invisible at frame rate. This is the one thread outside the
box/pool model, kept minimal on purpose: it never blocks, never coordinates
tightly. (The **renderables rebuild** upstream of it can still be the
self-re-arming FIFO single-in-flight pool iterator of pattern 6's shape.)

**SoraMech implication.** SoraMech's runner exits at quiescence and has no notion
of a consumer that outlives the graph's idle. Embedding a real-time consumer
alongside a long-running map is a pattern worth naming: the graph owns
*computation*, the consumer owns *presentation*, and a latest-wins slot is the
membrane between them.

---

## 8. Demand-driven getters: a box can be "ready" before all its inputs exist

A box normally fires when *all* its input slots are filled. But sometimes a value
a box will eventually need isn't ready when the box could otherwise start — e.g.
a record is appended to the arena (pattern 5) immediately, so the producer is
*confirmed ready* and runs, but that record's sorted *index* is computed later.
Blocking the whole box until the index exists wastes work it could already do.

**Mechanism.** Split "having an input" from "demanding an input." A box starts on
the inputs it has. A specific not-yet-ready value is reached through a **getter**
— itself a tiny SoraMech-style box, not a whole thread — that *pulls* the value:
if it has been published, the getter returns it and the consuming box proceeds;
if not, the getter can't fill that input yet, so the consuming box *suspends at
that point* until the value is published. This is pull/demand resolution inside
an otherwise push-driven graph: readiness is per-input-at-point-of-use, not
all-inputs-before-firing.

The payoff: producers that write-now-and-index-later let consumers start early
and stall only at the exact moment they truly need the late value — maximizing
overlap. (Relatedly, links in pattern 5 may point *backward* in the arena; fine,
because the compaction pass gathers values by following links and rebuilds them
linearly regardless of physical direction.)

**SoraMech implication.** SoraMech today spawns a box when all its input ports
have a value (`slot_has_value` across the ports). The getter is a *different*
readiness model — demand-driven, suspend-at-use — that SoraMech lacks. Worth
considering upstream as a "lazy input" port kind: a port pulled on first use that
parks its box if absent, rather than gating the whole box's spawn.

---

## Sharing

Canonical file: `docs/soramech-notes.md` in First Person Spellcraft. The SoraMech
project's `documentation` orphan branch carries a **symlink** to this file (not a
copy) — a pointer on a branch that holds nothing but the cross-project notes
index. Because it's a symlink, edits here reflect with no re-copy; and if this
project is ever deleted the link dangles as a harmless tombstone rather than
leaving a stale copy behind. (Git tags name commits, not files, so an orphan
branch — not a tag — is the right tool for "a place that holds only these notes".)
