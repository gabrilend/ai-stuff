# Threading model

The whole point of the system above the C layer is that it's a
soramech map running across a thread pool. This document describes
the primitives in the thread pool that make that safe on ARM.

## The firing rule

A soramech box has a set of input slots. Each slot can hold one or
more values, queued in a small ring buffer. When every slot has at
least one value waiting, the box is *ready to fire* — meaning a
task can be constructed that consumes one value from each slot,
runs the box's function, and writes the box's return value
somewhere downstream boxes can read it.

The interesting question is: who decides "the box is ready to
fire," and when, and how do they avoid stepping on each other?

## The gathering function

Per box, there is a critical section. We call it the gathering
function. It is protected by a single small atomic — only one
thread in the system can be running the gathering function for a
given box at a time. Inside, the gathering function:

1. Looks at every input slot's ring buffer.
2. If every slot has at least one value, pops one value from each
   into a small local array, and notes that a fire is possible.
3. Releases the atomic.
4. Builds the task struct from the popped values.
5. Enqueues the task on the thread pool's work list.

The order matters. Steps 1-2 are the actual decision. Step 3
releases the lock. Steps 4-5 are construction work that doesn't
need the lock to be safe. The hot loop is steps 1-3. Steps 4-5 are
paid by the thread that already won the gathering race, on its own
time, with no other thread waiting on it.

This shape is sometimes called "decide under the lock, act outside
the lock." It is much faster than the naive version (which holds
the lock until the task is enqueued) because contention on the
gathering atomic stays bounded by how long it takes to scan and
pop the input buffers, not by how long it takes to build and
enqueue a task struct.

## Why one atomic per box, not one atomic per slot

A slot-level atomic would let two producers (writing into different
slots of the same box) make independent decisions about whether the
box is ready. Two independent decisions can both conclude "not yet"
and the box never fires, or both conclude "now" and the box fires
twice. A box-level atomic forces the decision through a single
point. Exactly one thread sees the moment the last slot got filled.

## Unique return slots

Every task struct, when created, is assigned a unique location in
the ring buffer where its return value will be written. Two tasks
created from different boxes (or from the same box firing twice)
never share a return slot. This eliminates producer-side write
collisions by construction — no two tasks can race to write the
same memory.

The unique-slot rule and the gathering function compose. The
gathering function decides *when* a task gets enqueued; the
unique-slot rule decides *where* its output goes. Together they
mean every fire has exactly one producer of its output, and that
producer has no contention on the write.

## Visibility on ARM

ARM has a weak memory model. When a CPU core writes a value into
memory and then writes a flag saying "value is ready," another
core watching that flag can legally observe the flag go true
before it observes the value land. This is not a bug; it is how
the hardware delivers performance.

The fix is *memory ordering* on the atomic operations that
publish "a value is ready." When the producing task finishes and
the system updates the bookkeeping that makes the value visible
downstream, the publishing atomic operation happens with
*release* ordering — meaning every write the producer did before
the publish is guaranteed visible to any thread that sees the
publish happen. The consumer's load on that bookkeeping happens
with *acquire* ordering — meaning every write the producer made
before its release is visible to the consumer after its acquire.

C11's `stdatomic.h` gives us this directly. We don't write
separate barrier instructions. We specify `memory_order_release`
on the producing atomic operations and `memory_order_acquire` on
the consuming ones, and the compiler emits the right barriers for
ARM. The barriers are not extra code; they are the right flavor
of the atomic operations we are writing already.

## What every layer above this inherits

Drivers are boxes. The compositor is boxes. Apps are boxes. The
shape of the firing rule is the shape of how everything in the
userland thinks about concurrency. Get the firing rule right and
the rest is composition.
