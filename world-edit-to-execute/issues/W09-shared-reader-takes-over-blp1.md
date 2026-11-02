# Issue W09: The Shared Reader Takes Over BLP1 (an idea, not to be built yet)

**Phase:** W - WoW Client Bridge
**Type:** Idea
**Priority:** Low
**Dependencies:** W01 (the binding to the shared reader), and both BLP readers settled
**Blocks:** nothing
**Related:** 117 (this project's BLP1 reader), W01

---

## Current Behavior

Two BLP readers, one per version of the format:
- **BLP1 (WC3):** `src/parsers/blp.lua`, this project's own Lua reader
  (built by 522, finished by 117). The renderer, editor and asset tools use
  it.
- **BLP2 (WoW):** the custom client's C library, `libwreaders.so`, which
  W01 binds. W01's binding isn't built yet.

On 2026-11-02 the build session decided (on the owner's standing word to
answer open questions, issue 117 open question 2, Q-9) that BLP1 **stays**
in this project's own reader. Merging it into the shared library would tie
this project to the custom client's for a reader that already works, and
that is its own change, best made once both readers are stable.

## Intended Behavior

If it is ever wanted: BLP1 decoding is added to the shared library, this
project reads WC3 textures through W01's binding, and `src/parsers/blp.lua`
is retired. One library then reads both versions of the format, as the
owner first asked on 2026-09-26 ("same reader").

## When to Pick This Up

Not before all of these hold:
1. W01's binding is built and used by Phase W.
2. The shared library's BLP2 reader has stopped changing.
3. The Lua reader has had no fixes for a while (it has a full test,
   `src/tests/test_blp.lua`, and decodes every texture in the test maps).

## Suggested Implementation Steps

1. In the custom client's project: add BLP1 (JPEG and palette kinds, every
   alpha depth) to its BLP reader, with the errors `blp.lua` gives (mipmap
   and byte).
2. Expose it through W01's binding with `blp.decode_all`'s output shape.
3. Run `src/tests/test_blp.lua` against the binding, and compare all 2,046
   mipmaps in the test maps byte for byte with the Lua reader.
4. Switch the callers of `parsers.blp` over; retire `blp.lua` and `jpeg.lua`.

## Acceptance Criteria

- [ ] The shared library decodes every BLP1 mipmap in the test maps to the
      same bytes as `src/parsers/blp.lua`
- [ ] `src/tests/test_blp.lua` passes against the binding
- [ ] No second BLP reader is left in this project

## Related Documents

- `issues/completed/117-read-wc3-textures.md` (open question 2)
- `issues/W01-read-the-wow-client-archives.md`
- `issues/CRITICAL-PATH.md` (decisions, 2026-11-02)
