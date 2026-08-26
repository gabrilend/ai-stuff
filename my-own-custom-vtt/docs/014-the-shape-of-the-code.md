# The shape of the code

How the source is arranged, so that reading it from the lowest number upward is
an explanation of the project rather than a record of what got written first.

## Numbering is one sequence across the whole project

Every file that is part of the story carries an index at the front of its name,
and the indices are **one sequence across every directory**, not one per
directory. The highest one currently in use is in `.file-index-counter` at the
project root; a new file reads it, takes the next, and writes it back.

The documents in `docs/` come first because they are what a person reads first.
The source in `src/` continues from where the documents stop. A reader going from
the lowest number to the highest gets the argument, then the implementation of the
argument, in that order.

Renumbering is allowed and expected. When it happens, every reference to the old
name is rewritten by the tool that does the renumbering -- not by hand, and not
left to be discovered later.

### The bands

| Band | Contents |
| --- | --- |
| 001-016 | The documents. What this is and why it is shaped like this. |
| 017 onward | The server, in dependency order: arithmetic, then the world, then geometry, then sight, then the tick, then the network, then the rules host. |
| after the server | The client bridge, then the generators. |
| a high band, well clear of everything | `libs/`. Third-party code, renumbered up here so a reader can skip a contiguous range without wondering what they missed. |

The point of a high band for libraries is skippability. A reader who wants to
understand this project should be able to say "everything from here to here is
not ours" and jump.

## Every source file has a companion

Beside `023-sight.c` sits `023-sight.info.md`. The companion lists what the file
offers to the rest of the program -- each external function, what goes in, what
comes out, and what it is for -- treating the file as a black box.

**Prefer reading the companion over reading the source**, unless the question is
about a specific bug in a specific function. The companion is the interface; the
source is how the interface is kept.

When a function's signature or behaviour changes, its companion changes in the
same edit. A companion that has drifted from its file is worse than no companion,
because it looks authoritative.

## Conventions inside a file

**Every function is wrapped in a vimfold**, opening with a comment naming the
function without its arguments, then the definition:

```c
/* {{{ static int sight_sweep_endpoints */
static int sight_sweep_endpoints(struct world *w, uint32_t eye, struct fan *out)
{
    ...
}
/* }}} */
```

The fold closes on its own line below the last line of the function.

**Every branch is commented with what each path means.** Not what the condition
tests -- the code says that -- but what the world is like down each side. A branch
and its comment are one artefact and are always changed together.

**Indices, never pointers, for anything in the world.** A `uint32_t` into an
array. Pointers into world arrays break the moment an array grows, break silently,
and cannot be written to a snapshot.

**Zero is a sentinel and nothing is ever nil.** Index 0 of every array is a
reserved empty record. There are no null checks in the hot paths; there is a
validator that runs once. See [the world and its tick](004-the-world-and-its-tick.md).

**Dispatch tables, not switch statements.** The tick's passes, the command verbs,
the ruleset's hooks, the generator's stages. In every case the value already knows
what it means and the table says what knowing that means. The payoff is not speed;
it is that the order of the simulation is a piece of readable data instead of
something buried in a function body.

**A fallback is a warning and a warning is an error.** Nothing quietly substitutes
a default. A validator that cannot find what it needs names what was missing and
where, and stops.

## Threads

One pool, built once at startup, sized from the machine. The tick's parallel
passes hand it a range and a function -- "records 0 through 4999, run this" -- and
wait. There are no locks inside a parallel pass, because
[buffer-then-resolve](004-the-world-and-its-tick.md) means no pass writes where
another instance of itself reads.

Nothing in this project does batch work on one thread when the work is
parallelisable. Sight is the obvious case and the expensive one.

## Assembly

The angular sweep in [sight](007-sight-and-what-it-remembers.md) and the
fixed-point arithmetic under it are the two places where hand-written assembly
would pay, and they are written to stay open to it: flat arrays, no pointer
chasing, no branching on data inside the inner loop, one arithmetic shape
repeated.

That does not mean writing assembly now. It means not writing C that would have
to be restructured before assembly became possible -- which is mostly a matter of
keeping the data flat and the inner loop dumb.

## Tests

Tests are cheap, so there are many, and they run during the build. Three kinds
matter most here:

- **Leak tests.** Does a viewer's outbound stream contain something they must not
  know? See [what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md).
- **Determinism tests.** Run a session twice, compare the world hash at every
  tick. Catches a float creeping in, a wall clock in a ruleset, an unordered
  iteration.
- **Generator tests.** Does the generated world satisfy the description it came
  from? See [content is generated](013-content-is-generated.md).

When a bug is fixed, a test is written that fails on the old behaviour. The reason
is never "an issue file asked for one" -- it is that the thing has to actually
work, and the test is the only durable statement of what working means.

## Read next

- [The roadmap](015-roadmap.md).
