# 702 -- The hooks are a dispatch table

**Phase:** 7, the rules layer
**Blocked by:** [701](701-luajit-lives-in-the-server.md)
**Blocks:** [705](705-a-ruleset-may-refuse.md),
[706](706-what-a-viewer-may-know.md)
**Documents:** [the rules layer](../docs/011-the-rules-layer.md)

## Current behaviour

A Lua state exists and nothing calls into it.

## Intended behaviour

A ruleset provides the hooks it cares about. The rest are the empty function.

| Hook | When | For |
| --- | --- | --- |
| `on_load` | Once, at startup | Catalogues, kinds, sheet storage. |
| `on_command` | Gate 6, per command | Permit, or refuse with a sentence. |
| `on_action` | Per `RULES_ACTION` | **Where a whole game lives.** |
| `on_tick` | Pass 5, per beat | Timers, ongoing effects, anything with a duration. |
| `on_region_enter` | On a crossing | "When they enter the tavern." |
| `on_interact` | Per `INTERACT` | Opening the door, picking up the cup. |
| `may_know` | Per viewer, per thing, in the filter | Which sheet fields this viewer may be told. |
| `describe` | Per kind, once | What the view is told about appearance. |

Adding a hook is adding a row — the same discipline as the tick's passes and the
command verbs.

### `on_action` is the whole point

Everything the server does not understand arrives there with a scope attached.
Casting, attacking, searching, initiative — all of it, through one door. The
server never grows a case for any of them.

### A missing hook is not an error

A ruleset that provides only `on_command` is a legal ruleset. The empty function
is the default, and calling into Lua at all is skipped when a hook is absent —
because the cost of a call that does nothing, made per body per beat, is not
nothing.

### The crossings already exist

Phase 3's region pass collects crossings and delivers them in index order,
specifically so a ruleset sees them the same way every run. `on_region_enter` is
what that has been waiting for.

## Suggested implementation steps

1. Resolve the hooks once at load into references, not by name at call time — a
   string lookup per body per beat is a cost nobody would choose.
2. Record which are present, and skip absent ones entirely.
3. Call `on_tick` from pass 5 of the tick table, which has been an empty row
   since phase 3.
4. Deliver crossings after the barrier, on one thread, in index order.
5. Write the companion `.info.md`, listing the hooks and their arguments — that
   list is the contract a ruleset is written against.
6. Test a ruleset with no hooks at all, and one with every hook.
