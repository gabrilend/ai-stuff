# Phase 7 — The rules layer

**Goal:** the server stops being a game and becomes something games run on.

**Status: complete.** All nine issues done. `./run-phase-demo 7` runs one world
under two rulesets and shows them disagreeing.

## The issues

| Issue | What it established |
| --- | --- |
| [701 LuaJIT lives in the server](completed/701-luajit-lives-in-the-server.md) | The sandbox, and what it removes. |
| [702 the hooks are a dispatch table](completed/702-the-hooks-are-a-dispatch-table.md) | Eight hooks, resolved once, absent by default. |
| [703 the ruleset owns the sheets](completed/703-the-ruleset-owns-the-sheets.md) | Storage the server allocates and never reads. |
| [704 the narrow window on the world](completed/704-the-narrow-window-on-the-world.md) | Eleven functions, and everything else absent. |
| [705 a ruleset may refuse](completed/705-a-ruleset-may-refuse.md) | Gate 6, and the difference between declining and failing. |
| [706 what a viewer may know](completed/706-what-a-viewer-may-know.md) | Narrowing only, and defaulting to nothing. |
| [707 dice come from named streams](completed/707-dice-come-from-named-streams.md) | Rolls the server witnesses and nobody can refresh away. |
| [708 two rulesets that disagree](completed/708-two-rulesets-that-disagree.md) | The test that this is an interface. |
| [709 the phase seven demo](completed/709-the-phase-seven-demo.md) | The capstone, including the holes. |

## What is built

`073-rules` — LuaJIT embedded and sandboxed, and `075-demo-phase-7` running the
identical world under both of them. And two rulesets in `rulesets/`,
deliberately unlike each other:

| Question | a game with rules | a table with none |
| --- | --- | --- |
| Turn structure | Initiative; refuses out of turn | None |
| Movement | Eight metres, refused past it | Unrestricted |
| What is public | `hp,armour,name` | Nothing |
| What kind 1 is | `goblin,green,small` | `token,blue` |
| Dice | One twenty-sided against a target | A pool of six-sided counting successes |

**Not one line of C differs between the two runs.** One ruleset proves an
interface exists; two prove it *is* one.

Neither is trying to be a good game. They are trying to be **different** — a
sample ruleset that aims at being good grows until it is the only game the
interface fits.

## The gauntlet finally has six gates

Gate 6 runs **between checking and performing**, which required splitting
`command_apply` into `command_check` and `command_perform`. A ruleset asked to
veto something that has already happened is not a veto.

The retcon path deliberately replays through the *plain* path, skipping the rules
gate: a retcon re-runs what was **already decided**, and asking a ruleset whose
state has moved on would let it refuse something it permitted the first time —
and the replay would stop reproducing the session it is replaying.

## Failing open, deliberately

A hook that raises is abandoned after eight failures. After that, commands it
would have vetoed are **accepted**.

Failing closed would freeze a table completely over one bad line in somebody's
homebrew — every command refused, no way to play on while it gets fixed. Failing
open continues the evening under no rules at all, which is worse than correct and
much better than stopped.

It is the right trade **only because the failure was announced loudly first**. A
veto that quietly stopped vetoing would be the worst of the three.

## The float check grew its first exemption

Lua's only number type is a double, so every value crossing the rules boundary is
floating point, and the build's floating-point check would have failed.

Exempted **by name, with a paragraph**, because an exemption without a reason is
the ban quietly ending. What it means: the determinism argument is relocated
rather than holed — what was banned in C was the compiler's freedom to reassociate
and fuse, and a VM executing bytecode one operation at a time has neither.

What it leaves open is transcendentals ([14.2](../docs/016-open-questions.md)).

## The largest known hole

**A rolled-back turn does not roll back the sheets.** Geometry returns; hit points
do not, because a snapshot is a memcpy of flat blocks and a Lua table is not that.

Three ways out, none taken — ruleset-provided snapshot hooks, generic
serialisation, or acceptance — and each is worse than it sounds.
`rules_sheets_survive_rollback` exists and returns 0 so a caller can **say** so,
and the demo shows an undone fight restoring positions and leaving wounds.

[14.1](../docs/016-open-questions.md). Shown rather than hidden, because a
rollback that looks like it worked is worse than one that visibly does not.

## Blocking open questions

- **14.1** — sheets and rollback. The largest hole in the project.
- **14.2** — can a ruleset make a replay diverge, through transcendentals?
- **14.3** — who reads a ruleset's error?
- **7.2** — stale ghosts, which `may_know` now has the shape to answer.

## What phase 8 inherits

A server with no opinions, and a `describe` hook whose answers nothing yet draws.


## Reopened later, and closed

[703](completed/703-the-ruleset-owns-the-sheets.md) shipped with a hole in it and
said so: a rolled-back turn restored geometry and not sheets, so an undone fight
put everybody back where they had been standing and left them bleeding. Open
question 14.1 called it the largest hole in the project and the demo showed it
happening.

Four phases later it was closed, and the issue was **reopened rather than a new
one written beside it**, because the fix belongs in the issue that built the
storage. History is more useful vertical.

What had been missed: the option "serialise the table generically" was rejected
for breaking *quietly* on a closure — and that is a property of one
implementation of it, not of the idea. A copier can know perfectly well what it
cannot copy. The whole difference between a good answer and a bad one is whether
it says so, and where.

The general shape, worth keeping: **when three options are rejected and the
problem stays open, check whether one of them was rejected for a fixable property
of a particular implementation rather than for something intrinsic.**
