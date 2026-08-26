# 1405 — The checker

Produces `src/095-constraint-check.lua`.

## Current behavior

**Done.** `src/095-constraint-check.lua` exists, and `./run-checks` at the
project root runs it and the diagram check together.

A failure line gives the tag, the file and line, the relation as written, both
sides evaluated in the unit their own symbols were declared in, the margin as a
percentage, and the author's reason. Dimension mismatch is reported apart from
failure because the two mean different things.

**Two categories were added while using it.** Zero is treated as dimensionally
neutral, because every literal is dimensionless and without the exception the
notation would forbid `x > 0`, which is the commonest constraint anybody writes.
And a constraint that reaches for a symbol nothing has declared yet is reported
under *not yet* rather than as nonsense, and does not fail the run -- the set
being incomplete is a different condition from the set being wrong, and during
construction it is the normal one.

## Intended behavior

**Evaluate every constraint in the blueprint set and report.** This is the program
that decides whether the project is finished.

### What a report line says

Not pass or fail. For a failure: the tag, the blueprint, the relation as written,
**both sides evaluated with units**, the margin by which it fails, and the reason
text the author gave for why it must hold.

`002` promises the reader can see how far off it is, and a report that says
`C-013-1 FAILED` delivers none of that. A report that says the left side is
forty-six millimetres, the right is forty-seven and a half, and the reason is that
the core must fit inside the cavity with clearance, tells somebody what to do.

### The comparisons

`<= >= < >` are ordinary. `==` compares exactly and is only correct for integers
and counts, so the checker should warn when it is used on a value with a fraction.
`~=` means agreement within one part in a thousand and is the most valuable
operator in the set, because it is what the three triple checks in `087` are
written with.

Both sides are dimension-checked before comparison. **A dimension mismatch is
reported separately from a failure**, because it means somebody wrote nonsense
rather than the design being too tight, and mixing the two in one list wastes the
reader's time.

### What else it reports

- Cycles, undefined references and duplicates, from `094`.
- Orphan symbols nothing uses.
- Symbols of kind `target`, counted and listed. **A blueprint set with targets in
  it is not finished** and the report should say so in those words.
- Blueprints with no constraints at all.
- The seam register's unguarded list from `087`, if it can be computed.

### The exit condition

Non-zero on any failure, mismatch, cycle, duplicate or undefined reference. Zero
with warnings on orphans and targets. So the program can be run from anything and
its answer believed.

### Where it writes

Nowhere except standard output and `tmp/shared-memory/`. No state, no cache, no
incremental mode. The whole set resolves in well under a second and a cache would
be a second source of truth.

## What the file must offer

A run over a directory. A summary count. The report. The exit code.

## Tests

- A fixture set with one deliberate failure reports exactly that one, with both
  sides.
- A dimension mismatch is reported in the mismatch section and not the failure
  section.
- `~=` accepts a part in ten thousand and rejects a part in a hundred.
- `==` on a fractional value warns.
- Exit code is non-zero for a failure and zero for a target.
- A blueprint with no constraints is named.

## Blocks

Every blueprint in the project, in the sense that none can be checked until this
exists.

## Blocked by

`1404`.

## Related documents

`001` and `002`. This is the deliverable's test.
