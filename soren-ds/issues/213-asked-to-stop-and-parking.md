# 213 — Asked to stop, and parking

## Current behavior

**There is no way to tell a program to stop, and no idea of what
stopping would mean.**

The design this engine follows has exactly one ending: work runs out,
the last worker to fall asleep looks once more, finds nothing, and
stops everybody. That is correct for a program somebody typed at a
prompt. It is wrong here in the most direct possible way — on a
handheld, every core asleep means the user has not pressed anything
yet.

## Intended behavior

**Programs on this device end because they were asked to. Running out
of work is not an ending; it is Tuesday.**

| all cores asleep means | on a workstation | on this device |
|---|---|---|
| the work is finished | yes — exit | no |
| nothing is pending right now | — | yes — idle the silicon (206) |

### A pipeline ends in a step that waits

The last thing in a chain is a station that will not run again until
somebody restarts it. The engine already has exactly the right
mechanism and it needs nothing new: **a port with no source configured
can never hold a value, so a station holding one can never become
ready.** It costs nothing while parked — nothing polls it, no delivery
arrives, no core ever looks at it.

```
   running   tail.in ←── upstream         becomes ready when fed
   parked    tail.in ←── (no source)      can never become ready
   restarted tail.in ←── upstream         runs again

   one field write in either direction.
```

### Being asked to stop

```
   1  unwire the program's inputs      nothing new can enter
   2  let what is in flight finish     ordinary delivery, ordinary runs
   3  the last value reaches the tail  which is parked, so it holds
   4  release the buffers              ← the interesting step
```

Step 2 needs no new machinery at all. It is the ordinary ending,
triggered early: nothing new arrives, the queue drains, the cores park.

### Parked memory is released but remembered

A parked program's ports may be holding many pages of cells, and a
device that is holding four parked apps is holding four programs' worth
of buffers for nobody.

**So the pages go back to the allocator, and the program remembers a
checksum over what they held.**

```
   parked:   pages returned to 203's free stripes
             │
             ├─ nobody needed them  →  still untouched
             │                          checksum still matches
             │                          restart resumes in place. free.
             │
             └─ somebody was handed one  →  contents changed
                                           checksum fails
                                           say so, rebuild from disk
```

This is a cache with none of the machinery of a cache. Reclaim is
already free — the allocator simply hands the page to whoever asks.
Detection is one checksum. There is no eviction policy, no reference
counting, and no bookkeeping that has to be kept correct.

**Two checks, cheap one first.** Are the pages still marked free in the
owning core's stripe? If any has been handed out, stop there — the
checksum cannot pass. Only if all are still free is the checksum worth
computing.

**A failed checksum is reported every single time, out loud.** Falling
back to disk quietly would turn a memory-pressure problem into a
mysterious slowness, and the whole point of noticing is being able to
say *this app had to be reloaded because something else needed its
pages.*

**The disk half belongs to phase 4**, where there is a filesystem to
reload from. Until then a failed checksum means the program is rebuilt
empty and says so — which is the honest behaviour, not a placeholder.

## Suggested implementation steps

1. A stop operation: take a list of stations, unwire their inputs, and
   report when the last in-flight task belonging to them has finished.
2. "Belonging to them" needs an answer — see the open questions.
3. Releasing a parked program's port pages, with the checksum taken as
   they are released.
4. The restart path: check the stripe bits, then the checksum, then
   either resume in place or rebuild.
5. A test that a parked program consumes no cores and no cycles —
   asserted from the per-core counters, not by watching.
6. A test that a program parked and immediately restarted resumes with
   its buffered values intact.
7. A test that a program parked, then deliberately starved of memory by
   another allocation, fails its checksum, says so, and rebuilds.

## Open questions

- *How does the engine know which stations belong to one program?*
  There is no map object — a program is whichever stations are wired to
  each other — so "this app's stations" has to be either a list
  somebody keeps, or something discovered by walking the wiring from a
  known root. A list is simpler and can go stale; a walk is always
  right and costs a traversal. This wants deciding before 214 asks the
  same question in a smaller form.
- *What about a value that arrives at a parked station's ring port?*
  It sits in a cell and waits. Harmless, and invisible. If the parked
  program is later rebuilt rather than resumed, it is silently
  discarded, which is the kind of quiet loss worth at least counting.
- *Should the checksum cover the wiring as well as the buffers?* The
  station records are never released, so they cannot be reused
  underneath us — but a stray write from another program can still
  reach them, since nothing protects memory until phase 9. Checksumming
  the skeleton too would catch it, at the cost of a walk on every park.
- *What asks?* The compositor when an app leaves the screen, the user
  through a menu, the system under memory pressure. All three are later
  phases; what this issue owes them is that the operation exists and
  means one thing.

## Blocked by

206, 212.

## Blocks

215.

## Related

- [206 — Sleeping and waking](206-sleeping-and-waking.md), which idles
  rather than concluding
- [208 — What an input port is](208-what-an-input-port-is.md), whose
  *none* state is the parking mechanism
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  the same mechanism one scale down
- [013 — Background app lifecycle](../docs/013-background-app-lifecycle.md),
  which will be the first caller
