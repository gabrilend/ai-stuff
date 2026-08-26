# 1408 — Checking the drawings

Produces `src/098-diagram-check.lua`.

## Current behavior

Nothing. `002` requires every dimension in a drawing to be a bracketed symbol name
and nothing verifies it.

## Intended behavior

**Read every drawing in every blueprint, extract every bracketed name, and fail if
one is not a symbol that exists.**

### Why this is worth a program

A drawing is the part of a specification a person actually builds from, and it is
the part most likely to be wrong, because a drawing with a number written on it
does not participate in any of the checking the rest of the project does.

`002`'s rule — write `[L_cube]`, never `60` — is what puts drawings inside the
system. **This program is the only thing standing between the project and a
drawing that says sixty after the cube has become sixty-four.**

### What it must also catch

**A number where a name should be.** A bare dimension figure in a drawing is the
failure this exists to prevent, so the checker should look for digit sequences in
drawing bodies that appear to be dimensions and warn. It cannot be exact — a
drawing may legitimately contain `2x` or a corner label like `C011` — so this is a
warning with a suppression marker, not an error, and the blueprint should say so
rather than pretending to certainty.

**A drawing with no dimensions at all.** Sometimes right, often a drawing that was
never finished. Reported to `096`'s coverage list.

**A caption missing.** `002` requires one on the line after the fence.

### What it deliberately does not do

Check that the drawing is *correct* — that the box is the right size relative to
the other box, that the arrow points the right way. Nothing can, short of turning
ASCII into geometry, and pretending otherwise would give false confidence. The
blueprint should state the limit plainly: **this program checks that a drawing
refers to things that exist, and nothing about whether it depicts them
truthfully.**

## What the file must offer

Scan a directory. Report unknown names with file and line. Report suspected bare
numbers as warnings. Report missing captions and dimensionless drawings. An exit
code.

## Tests

- A drawing referencing a real symbol passes.
- A drawing referencing a misspelled symbol fails and names it.
- A bare number in a drawing warns.
- A suppression marker silences the warning.
- A missing caption is reported.
- A drawing with no bracketed names is reported to coverage, not failed.

## Blocks

`1409`.

## Blocked by

`1403`, `1404`.

## Related documents

`002` for the bracket rule.
