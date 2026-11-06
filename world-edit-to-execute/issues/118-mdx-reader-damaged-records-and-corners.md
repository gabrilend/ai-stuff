# Issue 118: The Model Reader on Damaged Records and Stray Corners

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** 522 (the model reader `src/parsers/mdx.lua` and `src/assets/gpu.lua`)
**Related:** 116 (read WC3 models), the W client's issue 401 step 2 (the
C twin `src/061-mdx.c`, gabrilend/custom-client#2), `docs/wow-client-bridge.md`

---

## Current Behavior

Found while writing the reader's C twin in the W client (401 step 2):

1. **A record whose size is 0 is read forever.** Materials, geosets and
   the records round a node (attachments, lights, particle emitters,
   ribbons) end with `r.pos = start + size`; with a size of 0 the reading
   goes back to the record's own start and reads it again, without end.
   Geoset animations, bones, helpers, event objects, collision shapes,
   texture animations and material layers move on, but read a record
   whose size says it isn't there.
2. **16-bit and 8-bit reads don't check the file's end.** `R:u32` and
   `R:f32` stop with "MDX: read past the end"; `R:u16` (triangle corners)
   and `R:u8` (vertex groups) read past the end of the reader's buffer and
   go on, so a list cut by the file's end fails later with a misleading
   message ("expected GNDX, found "), or not at all.
3. **A triangle corner past its geoset's points goes to the card.**
   `gpu.lua` copies corner numbers as the file has them, so a corner
   numbered 9 in a geoset of three points makes the card read past the
   mesh. The C twin maps such a corner to the geoset's first point, as the
   W client's M2 reader does; the two disagreed there.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #238 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- The model exporter (`src/assets/tool.lua`) has its own copy of the triangle loop and still writes out-of-range corners, producing invalid glTF. Put the rule in one shared triangle-list helper.
- The renderer's new `if c then` drops a missing corner, shifting every later corner by one; the reader should refuse a PCNT total larger than the corner list.
- The record check only refuses sizes under 4; a record shorter than its fixed fields still reads them from the next record.
- Nothing checks that track reading stopped at the record's end, so a large key count reads into the next record.
- The 16-bit and 8-bit end checks test the end of the file, not the record, so a short list reads following chunks.
- Tangent and skin-weight skips, tag and string reads still run past the end unchecked; this issue lists that as still open, so it isn't complete.
- Cameras get no record check, so the Lua and C readers disagree on the same model; the event-frame count isn't checked either.
- New files and the new reader method lack info files and folds.

## Intended Behavior

1. Every record that starts with its own size is read through one check
   (`R:record`, as the C twin's `record()`): a size under 4 can't move the
   reading on, and a size past its chunk's end isn't the record's own;
   both stop the reading with an "MDX: a record in ... of N bytes, ..."
   error. Cameras are left as they were: the C twin passes over them.
2. `R:u16` and `R:u8` check the end as `R:u32` does and stop with the same
   "MDX: read past the end".
3. `gpu.lua` hands the card a corner past its geoset's points as the
   geoset's first point (0), so the Lua and the C give the same corners.
   The reader itself keeps the corner as the file has it.

## Suggested Implementation Steps

1. `mdx.lua`: `R:record(stop, what)`, used by materials, their layers,
   geosets, geoset animations, nodes (bones, helpers, events, collision)
   and the records round a node, and texture animations.
2. `mdx.lua`: end checks in `R:u16` and `R:u8`.
3. `gpu.lua`: the corner rule in `geoset_arrays`.
4. Tests built byte by byte, needing no maps.

## Acceptance Criteria

- [x] A material, geoset, attachment or particle emitter of size 0 is refused, not read forever
- [x] A layer, geoset animation, bone, helper or texture animation of size 0 is refused
- [x] A record larger than its chunk is refused
- [x] 16-bit and 8-bit lists cut by the file's end are refused with "MDX: read past the end"
- [x] A corner past its geoset's points reaches the card as the geoset's first point
- [x] Every model in the test maps reads exactly as before (592 models, compared field by field)
- [x] Tests: `src/tests/test_mdx_damaged.lua` (20)

## Notes

- Once this is merged, the W client's `tests/062-mdx-matches-lua.lua` no
  longer has a decided difference to allow for: its corner check can
  compare gpu.lua's corners with the C's directly.

## Implementation Notes

- `src/parsers/mdx.lua`: `R:record` (start and end of a record, refusing a
  size under 4 or past its chunk); `read_node` takes its chunk's (or its
  outer record's) end; `R:u16` and `R:u8` check the end.
- `src/assets/gpu.lua`: in `geoset_arrays`, a corner `c >= nv` becomes 0.
  There is no `gpu.info.md`.
- `src/tests/test_mdx_damaged.lua`: parses run under an instruction budget
  (count hook, JIT off), so a reading that loops fails its test instead of
  hanging. Against the code before this issue, 16 of its 20 tests fail
  (four of them by the budget).
- Checked: every one of the 592 distinct models in `assets/*.w3x` and
  `*.w3m` parses to the same table before and after (one,
  `File00000129.mdx` in War-in-the-Plaguelands-[24]-B6a.w3x, is refused
  before and after, at its collision shapes). `test_assets` 28/28,
  `test_effects` 32/32, `test_lightning` 33/33, `test_wc3map_scene` 38/38,
  `test_editor` 83/83, `test_imports` 42/42.
- Still open, not part of this issue: `test_anim`'s last section parses
  every map model without `pcall` and stops at that refused model (on main
  as well); `R:tag` and `R:str` past the end give short strings rather
  than an error (they read through `string.sub`, so never past the buffer).
