# 006 — Phase 0 demo: the crown in three formats

**Phase:** 0 — Tools
**Blocked by:** 001, 002, 003, 004, 005

## Current Behavior
Built and run: `issues/completed/demos/phase-0-demo` with its table in
`phase-0-compare.lua` beside it, and `scripts/make-test-shapes`. All four
files keep 2220 triangles and the 90 mm height; the largest corner shift is
float rounding (thousandths of a micrometre). Stays open while 003 and 005
hold open questions.

## Intended Behavior
The crown sketch written out as glTF, OBJ, text STL and binary STL, each read
back and compared (triangles, parts, size, bytes on disk, read time) in a
printed table, then each opened in the viewer, turned, and photographed; the
four photographs and the table are the demo's output.

## Suggested Implementation Steps
1. `scripts/make-test-shapes`: writes the shapes into tmp/shared-memory/.
2. `issues/completed/demos/phase-0-demo`: table, then viewer runs.
