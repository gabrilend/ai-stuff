# 703 -- The ruleset owns the sheets

**Phase:** 7, the rules layer
**Blocked by:** [702](702-the-hooks-are-a-dispatch-table.md)
**Blocks:** [706](706-what-a-viewer-may-know.md)
**Documents:** [a thing in the world](../../docs/005-a-thing-in-the-world.md),
[the rules layer](../../docs/011-the-rules-layer.md)

## Current behaviour

**Done, and the reopening is done too.**

Sheets are Lua tables in the registry, one per index, in whatever shape the
ruleset likes. The server allocates and never reads one.

**And a rollback puts them back.** `rules_sheets_survive_rollback` returns 1.
`073-sheet-copier.lua` deep-copies the sheet table at the head of every turn and
copies it back on a rollback, and it lives in the registry where a ruleset cannot
reach it -- so nothing in C ever looks inside a sheet.

A value it cannot copy stops the snapshot with a sentence naming the path:

    the sheets could not be copied: sheet.2.attack holds a function

A turn whose sheets could not be copied is **not rollbackable**, and
`session_why_not_rollbackable` gives that sentence. The refusal happens before
anything is restored, so the world is left exactly where it was. It does not stop
play: that one turn cannot be taken back and everything else carries on, which is
the same argument that makes an abandoned hook fail open.

A sheet's metatable refuses a function at the moment it is stored, naming the
field. A ruleset can call `setmetatable` and take the guard off, so the copier
validates as well -- **the guard is for the message, the copier is the
authority** -- and there is a test that removes the guard and checks the copier
still refuses.

Cycles are refused rather than flattened, because flattening one turns what the
ruleset stored into a different shape that looks similar and the ruleset would go
on using it.

Ring slots forget their snapshots when they are reused. Without that the
snapshots table would hold every turn ever played, which is a leak that only
appears on a long evening.

### What it cost

One Lua file, three C functions, one field and a sentence on a turn state, and
the phase 7 demo changed from showing a hole to showing a restore.

The four phases it was open were not wasted: the demo showed it failing the whole
time, `rules_sheets_survive_rollback` existed so a caller could say so, and open
question 14.1 named it as the largest hole in the project. **Nothing was ever
pretending.** That is what made it safe to leave open, and it is the difference
between a known hole and a bug.

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
they point at, unless something snapshots them too. Three options were written
down when this issue was first built, and all three were rejected:

| Option | Cost |
| --- | --- |
| Ruleset provides `snapshot`/`restore` hooks | Every ruleset author must get it right, and one who does not produces a rollback that silently half-works. |
| Server serialises the sheet table generically | Only works for plain data — no closures, no upvalues — and quietly breaks on anything else. |
| Sheets do not roll back | Honest, cheap, and wrong in a way people will notice. |

The third was taken for phases 7 through 11, with `rules_sheets_survive_rollback`
returning 0 so that a caller could *say* so rather than pretend. It was recorded
as open question 14.1 and described as the largest known hole in the project.

### Reopened: there is a fourth option, and the second one's cost was misread

The second option was rejected for breaking "quietly". **That is a property of
one implementation of it, not of the idea.** A generic copier can know perfectly
well what it cannot copy — a function, a userdata, a coroutine — and the whole
difference between a good answer and a bad one is whether it says so.

So: sheets are deep-copied at the head of every turn and copied back on a
rollback, and **anything that cannot be copied stops the snapshot with a sentence
naming where it was found.**

Three things make that safe rather than clever:

**The copier is Lua, not C.** It lives in the registry where a ruleset cannot
reach it, and C only ever says "copy" and "put back". So the rule at the top of
this issue stays literally true: the server still never reads a sheet.

**A turn that could not be snapshotted is not rollbackable, and says which turn
and why.** It does not stop play, it does not half-copy, and it does not roll
back to something approximate. `session_can_roll_back_to` already answers this
question for turns that fell out of the ring; this is the same answer for a
different reason.

**A write of something uncopyable is refused where it happens.** A sheet's
metatable rejects a function at the moment it is stored, naming the field — so
the ruleset author learns at the line that did it rather than at the next
rollback. The copier still validates, because a ruleset can call `setmetatable`
and remove the guard; the guard is for the error message and the copier is the
authority.

### What this does NOT change

**The server still never interprets a sheet.** Copying a value without asking
what it means is not reading it in the sense this issue forbids -- the same
distinction the world file writer already relies on when it copies a `kind` it
has no opinion about. The line is: *the server may copy a sheet; it may not
interpret one.*

**A ruleset can still put anything in a sheet** that is data. Numbers, strings,
booleans, and tables of those, nested as deep as it likes. What it cannot do is
put a closure in one and expect a rollback to work — and it now finds that out
immediately rather than in an evening six weeks later.

## Suggested implementation steps

1. A registry table in the Lua state, keyed by sheet index.
2. Allocate on request, free when a thing is destroyed.
3. **Never read it from C.** If C ever needs to know what is in a sheet, the
   system-agnostic claim has been broken somewhere upstream.
4. A Lua chunk in the registry that deep-copies the sheet table, refusing
   anything that is not a number, a string, a boolean or a table of those, and
   naming the path where it found it.
5. A metatable on each sheet that refuses an uncopyable value at the moment of
   storing, naming the field.
6. The session snapshots sheets with the world and puts them back on a rollback.
   A turn whose sheets could not be copied is marked not-rollbackable, with the
   reason kept.
7. `rules_sheets_survive_rollback` returns 1, and the phase 7 demo stops
   demonstrating a hole and starts demonstrating a restore.
8. Test: a sheet field survives a rollback; a sheet holding a function is refused
   by name; and a turn that could not be snapshotted refuses to be rolled back to
   rather than half-restoring.
4. Make the rollback path report that sheets were not restored.
5. Write the companion `.info.md`.
6. Open the question about snapshotting sheets, and say in the demo that a
   rolled-back turn does not roll back the numbers.
