# Strategem — one file is the whole contract between two halves

The tapestry has a generation half (walk the disk, write dates) and a viewing
half (order, cursor, open). They share exactly one artifact: `catalog.jsonl`.
Not a function call, not a shared object in memory — a file on disk.

Because the contract is a single serialized file:

- A crash while scanning cannot corrupt the navigator; the navigator only ever
  sees a finished file.
- Either half can be rewritten in another language without touching the other.
- The seam is inspectable: you can `head` the contract and see the whole
  agreement.
- Tests for the viewing half need no disk walk — hand it a hand-written
  `catalog.jsonl`.

The generalizing pattern: **make the boundary between two subsystems a written
artifact, and let neither call into the other.** Coupling drops to the schema of
one file. This is the same shape as: a compiler's intermediate representation, a
build system's manifest, a scan→report pipeline, a producer writing a queue a
consumer drains. When two things must cooperate but must not entangle, put a
document between them and let the document be the entire relationship.
