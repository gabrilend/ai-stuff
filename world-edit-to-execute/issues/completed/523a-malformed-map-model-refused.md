# Issue 523a: A Malformed Model in a Test Map Is Refused, and Named

**Phase:** 5 (rendering)
**Type:** Implementation (tests)
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** 523 (`src/tests/test_anim.lua`), 522 (the MDX reader)
**Related:** 118 (MDX reader fixes, open pull request), A03 (the test runner's 2026-11-06 note)

---

## Current Behavior

Found when the test runner began testing the project's own `assets/`
(A03, 2026-11-06): `test_anim` stops in its last section, "The test
maps' models", with a Lua error, and reports nothing for that section.
The section calls `mdx.parse` on every model in every test map without
`pcall`, and one model in War-in-the-Plaguelands (added 2026-11-02),
`File00000129.mdx`, is refused: "MDX: read past the end".

The file is at fault, not the reader. Its last chunk, `CLID` (collision
shapes, 108 bytes), ends exactly at the end of the file. Its last shape,
node "Plane_Col", is of type 3 (a cylinder), whose vertices take 28 bytes;
the file has 8 bytes (two floats, both 100.0) after the type. Issue 118's
open pull request, which fixes other things in the reader, records the
same model as refused before and after its changes.

## Intended Behavior

- The section reads each model under `pcall`. A model that is refused is
  allowed only if it is on a list of known malformed models in the test,
  each with what is wrong with it, and only if the reader refused it with
  its own message (one that starts "MDX:"). Every other model that fails
  to read fails the test, with its map, name and error.
- The refused models are printed, so a run shows what was left out.
- The section's other checks stay as they were: 250 or more rigged
  models, and every pose of every sequence finite.

## Acceptance Criteria

- [x] `test_anim` runs to the end and passes (41 checks; 531 models rigged, 9,168 poses)
- [x] `File00000129.mdx` is reported as refused, with what is wrong with it
- [x] With the list empty, the new check fails and names the model and its error

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/tests/test_anim.lua`: the `malformed` list (map and model name, and
  what is wrong), `pcall` around `mdx.parse`, and the check "every model
  reads, but for the known malformed ones". Nothing outside the test
  changes.
- Across the 19 test maps there are 592 distinct models; this one is the
  only one the reader refuses.

### Decisions (2026-11-06)

- **The test changes, not the reader, and why.** Issue 523 asked that
  every model of the test maps be posed; it said nothing of a model that
  can't be read. This one can't: its data stops partway through a shape.
  The reader refusing it with a clear message is the right behaviour;
  making the reader accept it would mean inventing the missing 20 bytes.
- **A named list, not "any refusal is fine".** Allowing every model the
  reader refuses would let a reader bug that refuses good models pass
  unseen. Only the models listed, each checked by hand, may be refused,
  so the check stays as strict as before for every other model.
- **Kept apart from issue 118.** That open pull request rewrites much of
  `src/parsers/mdx.lua`; this change touches only the test, so the two
  don't conflict.

### Still open

- If a later map brings another damaged model, it is added to the list
  only after its bytes are checked, as this one was.
