# Soramech runtime — the Soren DS subset

The userland above the kernel is a soramech map running across
the phase 2 thread pool. The full soramech runtime described in
the parent project's docs at `/home/ritz/programs/sora/soramech/`
is rich — three languages, on-disk JSONL transcripts, an
encapsulation system, a reference-counted artifact cache. The
Soren DS runtime is a strict subset of that, shaped to fit on a
handheld and tied to the threading core we already built.

This doc describes which pieces of soramech we keep, which we
defer, and how the kept pieces attach to the kernel below.

## What we keep

The **map model** — boxes connected by wires — is identical to
soramech proper. A box has input ports on its left and one output
on its right. Wires live on the producer's `connections[]` array.
When every required input slot has a value, the box fires, its
function runs, and the output is pushed along the wires to
downstream consumers.

The **routing kinds** are all kept: `plain`, `comparator`,
`iterator`, `randomizer`, `weighted`, `distributor`,
`nonlinearity`. They are pure routing logic — they don't depend on
any runtime feature that a desktop has and a handheld doesn't.

The **slot store** is kept: per-port input slots, each with a
small ring buffer of cells. The unique-return-slot rule that
phase 2's threading core relies on is the same rule the slot
store enforces.

**All boxes are multi-spawn.** A box that is currently running
can be fired again from another thread; the runtime never gates
re-entry. Box authors are responsible for thread safety inside
their box functions — atomics for shared counters, no
unsynchronized static mutable state, careful synchronization for
anything that crosses the function-call boundary, or pure
functions that share nothing. The runtime guarantees that each
fire has its own input values (popped from the slots by the
gathering function before the task is queued) and its own unique
return slot for output, but the box function's own internal
state is the author's problem.

This used to be the one place Soren DS diverged from soramech
proper's runtime, and it is no longer a divergence: as of
2026-07-26 soramech proper adopted the same rule and retired its
single-spawn invariant outright. Both runtimes now say the same
thing.

The reason is parallelism: gating a hot box on its previous fire
bottlenecks exactly the boxes that most need to run in parallel.
Soramech proper had also found that the gate does not stay simple
— it needed an exemption for iterator routing and everything
downstream of it, which cost a load-time marker walk, a second
slot shape for the exempt boxes, and a rule for where the two
shapes meet. The cost of dropping it is on box authors, who write
thread-safe code. Both projects accept the cost.

The **firing rule** matches phase 2's gathering function exactly.
A box's gathering critical section sits behind one box-level
atomic; the gather decides the fire, the rest happens outside the
lock. This is not a coincidence — the threading core was built to
serve this runtime.

**Encapsulated sub-maps** are kept. A sub-map appears as a single
box on its parent's canvas with its own input ports (from
`external`-marked read boxes inside it) and its own output ports
(from `external`-marked write boxes). The load-time splice
machinery flattens nested encaps into the parent graph and
prefix-renames the sub-map's box ids. The four launch apps are
flat as their first cut, but the compositor, the input router,
the soramech runtime itself, and the modeller from phase 10 all
have natural sub-map structure that the encapsulation mechanism
expresses cleanly. Without it, every kernel-level map past about
four boxes deep becomes unmaintainable.

**The compile pipeline** is kept. A compile takes a map's source
(its `meta.json`, `boxes/*.json`, and `src/*.c` files) and
produces a runnable artifact — on Soren DS, a small directory
under `tmp/compiled/<map>/<generation>/` containing the compiled
box code and a manifest that lists which box names map to which
loaded function pointers. The compile pipeline is what makes
on-device authoring possible: the user edits a box's C source in
the editor, the editor saves the file, the runtime compiles it,
and the running map picks up the new box at its next quiescence
point. Phase 4 builds the in-tree compile path on top of the filesystem
that lands in the same phase; phase 6 wires it to the editor's
save action; phase 9 hardens it against the user writing a box
that crashes the system. Without the compile
pipeline, on-device authoring is impossible — the kernel image
would be the only universe of boxes, and the user would have no
way to add to it without rebuilding and reflashing.

**Reference-counted artifacts** are kept. A long-running app — the
messenger holding open a peer connection, the editor with unsaved
buffers — holds a reference on the specific compiled generation
its tasks are running against. When the user edits one of the
app's boxes and the compile pipeline rebuilds, the new build goes
to the next generation. The old generation stays alive until its
reference count drops to zero. This is what makes the rebuild
non-destructive to the running app: in-flight tasks finish using
old code, the slot store stays intact, and new fires pick up the
new code via the hot-swap mechanism described below.

## What we cut

- **Lua and Bash boxes.** Box functions are C only at launch. A
  later phase can add a userland language layer above the
  kernel; the kernel itself doesn't host a Lua runtime, a Bash
  helper process, or anything similar. See
  `009-deferred-work.md`.
- **Cross-language wires.** With one language, the slot store
  carries one representation. No JSON serialisation across the
  wire, no dual-ring per slot, no per-cell tag.
- **On-disk JSONL transcripts.** The transcript model is kept,
  but the transcript lives in a fixed-size RAM ring buffer and
  is consulted only for crash diagnosis. The handheld's storage
  is too small and too write-precious to absorb the full audit
  trail. See `009-deferred-work.md`.

## How boxes are implemented

A box that runs on Soren DS is a C function plus a small
descriptor. Two paths can produce one:

1. **Statically linked at kernel build time.** The launch system
   ships a curated library of boxes compiled into the kernel
   image — every box the four launch apps require, plus the
   routing kinds, plus the filesystem boxes from
   `011-filesystem.md`, plus the input event boxes from
   `004-input-model.md`, plus the display surface boxes from
   `005-display-and-compositor.md`. The kernel keeps a flat array
   of every descriptor compiled in.
2. **Compiled on-device into the artifact tree.** New boxes the
   user writes go through the compile pipeline described above.
   The output is loaded into a generation directory under
   `tmp/compiled/<map>/<generation>/` and registered with the
   runtime at the same descriptor shape as a statically-linked
   one. From the runtime's view, the two paths produce
   indistinguishable descriptors.

A box descriptor looks roughly like:

```c
typedef struct {
    const char *name;                    // "read-path", "comparator", ...
    const port_t *inputs;                // declared input ports
    int n_inputs;
    routing_kind_t routing;              // plain, comparator, iterator, ...
    int (*fn)(box_args_t *args);         // the actual function
    int generation;                      // which build of this box
    int refcount;                        // live tasks holding it
} box_descriptor_t;
```

The loader looks up boxes by name when reading a map's JSON. If a
named box has more than one generation alive (the user just
rebuilt a box that a running app still uses an older version of),
the loader resolves to the highest-generation one for new fires
while older generations stay reachable to the in-flight tasks
that already chose them.

A map on the SD card looks identical to soramech proper's map
directory format — `meta.json`, `boxes/*.json`, and `src/*.c`
files for the box source. The compile pipeline reads the source,
produces the compiled function, registers a new descriptor, and
the runtime picks it up.

The static-linking path is a launch-time bootstrap, not the
end-state. As more of the system migrates up into soramech maps
— the compositor, the input router, eventually the device
drivers — the bottom of the kernel keeps shrinking and the
compiled-on-device tree keeps growing. The static-linked library
is what the user starts with; the on-device authoring is how
they extend it.

## Hot-swap

A box's function pointer can be replaced atomically while the
map containing the box is running. This is the mechanism that
makes on-device authoring safe under live apps:

1. The user edits a box's C source in the editor and saves.
2. The compile pipeline reads the new source, compiles it, and
   produces a new function pointer at a new generation in the
   artifact tree.
3. The runtime publishes the new descriptor with a single atomic
   store: the box's named entry in the descriptor table now
   points at the new generation. The store uses release ordering
   so any worker thread that picks up the new descriptor sees
   every byte of the new function's code.
4. In-flight tasks that already entered the box keep running on
   the old generation. The old generation's reference count holds
   them. When they finish, they decrement the count. When the
   count reaches zero, the old generation is eligible for
   unmapping.
5. New fires of the box use the new generation. Because every
   box is multi-spawn, multiple in-flight tasks may already be
   running the old generation when the swap happens; they finish
   on old code, and only fires that begin after the swap pick up
   new code. The slot store mediates value flow between in-flight
   tasks of different generations through plain pointers — neither
   side has to know the other exists.

This is not a feature the launch system uses directly. Phase 8
ships the four apps without any hot-swap happening; they all run
statically-linked boxes for their first release. Phase 9 hardens
the MMU so a buggy user-compiled box cannot scribble over the
kernel. The first place hot-swap actually matters is the
on-device authoring loop — the user edits, saves, sees the
change immediately, without any app losing state.

## How a map runs

The runner is not a separate executable as it is in soramech
proper. The launch flow:

1. The user follows an inter-app link to "run this map" — or the
   compositor restores a backgrounded app whose map was already
   loaded.
2. The runtime asks the filesystem for the map's
   `meta.json` and `boxes/*.json`. The file boxes from
   `011-filesystem.md` do the actual reads.
3. The graph loader walks the JSON, looks up each box descriptor
   in the kernel library, attaches input slots, and stitches
   wires onto the producers' connections lists. This is a single
   pass — there are no encapsulations to splice.
4. Cycle detection runs on the assembled graph. A cycle is a
   load-time error; the load fails cleanly and the calling app
   gets the error back through the inter-app link's value
   channel.
5. The entry box is submitted to the per-app task queue
   described in `013-background-app-lifecycle.md`. The phase 2
   thread pool picks it up. The pool's gathering function fires
   downstream boxes as their inputs become ready.
6. When the work queue for this map is empty and no task is
   in-flight and no slot has queued values, the map has reached
   **quiescence**. A foreground map at quiescence sits there
   waiting for the user's next input event to push a value into
   its input boxes. A backgrounded map at quiescence is just
   idle — see `013-background-app-lifecycle.md` for what that
   does to the per-app queue.

## How a map produces visible output

The four launch apps each compose a map that ends in display
surface boxes. A display surface box is a `write`-shaped sink
that hands its input bytes to the compositor as the new contents
of the named surface (see `005-display-and-compositor.md`). The
surface marks itself dirty; the compositor's next damage scan
copies the pixels into the appropriate screen's framebuffer; the
display controller's scan-out makes them visible.

Apps do not call into the compositor directly. They wire a
display surface box into their map. The runtime delivers the
output value to the surface box's input; the surface box pokes
the compositor; the compositor takes it from there. This is the
same shape as the filesystem boxes: apps express their intent in
the map, and the runtime translates that into kernel calls.

## The RAM transcript ring

A fixed-size ring buffer in RAM records the last N events from
the running maps: task submits, task starts, task ends, fire
decisions, push results. The buffer is overwritten in place as
new events arrive. When the kernel panics, the panic handler
dumps the ring through the USB CDC-ACM stream (phase 1's
`110-usb-cdc-acm-debug.md`) so the developer sees the last few
hundred events leading up to the crash. The buffer's size is
tuned so the cost of writing it is invisible to the runtime —
the ring is a circular array, the writes are a single increment
and a single store per event.

This is the entire on-device debugging story for runtime issues.
A user holding the device who has not connected a laptop sees
the LEDs (`106-led-earliest-boot-signal.md`) and whatever the
panicking app last drew. A developer with a laptop attached sees
the transcript through the serial port.

## What's next

Phase 3 builds the loader, the wire connector, the encapsulation
splicer, and the task instantiator. The threading core under it
comes from phase 2. The filesystem boxes it reads maps through —
and the artifact tree it stores compiled boxes under — come from
phase 4. The display surfaces it speaks to come from phase 6.

`013-background-app-lifecycle.md` is the doc that describes how
a running map can be paused without being killed, and how a paused
map wakes up when something requires it.
