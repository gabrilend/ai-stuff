# 706 -- What a viewer may know about a sheet

**Phase:** 7, the rules layer
**Blocked by:** [703](703-the-ruleset-owns-the-sheets.md),
[704](704-the-narrow-window-on-the-world.md)
**Blocks:** [709](709-the-phase-seven-demo.md)
**Documents:** [what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

The outbound filter never sends a `sheet` index at all. Seeing a goblin does not
entitle you to its numbers, and there is no mechanism for it to entitle you to
some of them.

## Intended behaviour

`may_know(viewer, thing)` returns which sheet fields this viewer may be told.

The server asks and does not guess, because **which numbers are public is a
statement about the game**. Some systems show everybody's; some show none; some
show a creature's name once you have identified it and its hit points never.

### The gate order does not change

`may_know` runs **after** the four existing gates, on records that are already
being sent. It can only narrow, never widen — a ruleset cannot decide somebody
may know about a thing they cannot see.

That is worth enforcing in the code rather than trusting: the ruleset is handed a
thing the filter has already approved, and its answer selects fields.

### Free text is never handed over

The GM's notes are never sent to anybody without `MAY_SEE_HIDDEN`, **as a hard
rule in the server rather than a question put to the ruleset.**

A ruleset should not be able to leak the GM's notes by being written carelessly,
and the way to guarantee that is not to ask it.

### The default is nothing

A ruleset with no `may_know` hook sends no sheet fields, which is exactly the
behaviour phases 4 through 6 had. **Adding a rules layer must not widen what is
sent by default** — a system that becomes more revealing because somebody loaded
a ruleset that does not mention the subject has the default backwards.

## Suggested implementation steps

1. Call `may_know` per candidate thing per viewer, after the existing gates.
2. Expect a table of field names, or nil for none.
3. Encode those fields — which means the wire needs a form for named values, since
   the server does not know what the names are.
4. Cache per beat: the same viewer asking about thirty things should not mean
   thirty crossings into Lua if the answer is uniform.
5. Write the companion `.info.md`.
6. Test: no hook sends nothing; a hook narrowing correctly; a hook trying to
   widen being ignored; the GM's notes never appearing.
