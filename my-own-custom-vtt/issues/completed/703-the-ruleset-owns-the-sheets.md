# 703 -- The ruleset owns the sheets

**Phase:** 7, the rules layer
**Blocked by:** [702](702-the-hooks-are-a-dispatch-table.md)
**Blocks:** [706](706-what-a-viewer-may-know.md)
**Documents:** [a thing in the world](../../docs/005-a-thing-in-the-world.md),
[the rules layer](../../docs/011-the-rules-layer.md)

## Current behaviour

Every thing has a `sheet` field. Nothing ever reads it, and nothing ever sets it.

## Intended behaviour

The storage behind a thing's `sheet` index belongs to the ruleset, in whatever
shape it likes. **The server allocates and frees; it never reads.**

That is what makes this a system-agnostic tabletop. A server that knew what a hit
point was would not be one.

### It is a Lua table, keyed by index

The ruleset gets a table. The server hands out indices and says when one is no
longer needed. What a sheet *contains* — hit points, a stress track, a hand of
cards, nothing at all — is never the server's business.

A `sheet` of 0 means the ruleset has nothing attached, which is the normal state
of a coffee cup and must stay cheap.

### The awkward part: sheets are not world state

A world snapshot copies flat blocks of bytes. A Lua table is not that.

So a rollback restores the world's `sheet` **indices** and cannot restore what
they point at, unless the ruleset is asked to snapshot too. Three options:

| Option | Cost |
| --- | --- |
| Ruleset provides `snapshot`/`restore` hooks | Every ruleset author must get it right, and one who does not produces a rollback that silently half-works. |
| Server serialises the sheet table generically | Only works for plain data — no closures, no upvalues — and quietly breaks on anything else. |
| Sheets do not roll back | Honest, cheap, and wrong in a way people will notice. |

**This is a real problem and it is not solved by this issue.** Build the storage,
make the rollback path *say* that sheets were not restored rather than pretending,
and open a question. A rollback that restores geometry and not hit points is a
rollback that looks like it worked.

## Suggested implementation steps

1. A registry table in the Lua state, keyed by sheet index.
2. Allocate on request, free when a thing is destroyed.
3. **Never read it from C.** If C ever needs to know what is in a sheet, the
   system-agnostic claim has been broken somewhere upstream.
4. Make the rollback path report that sheets were not restored.
5. Write the companion `.info.md`.
6. Open the question about snapshotting sheets, and say in the demo that a
   rolled-back turn does not roll back the numbers.
