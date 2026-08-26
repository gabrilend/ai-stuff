# 704 -- The narrow window on the world

**Phase:** 7, the rules layer
**Blocked by:** [702](702-the-hooks-are-a-dispatch-table.md)
**Blocks:** [705](705-a-ruleset-may-refuse.md)
**Documents:** [the rules layer](../../docs/011-the-rules-layer.md),
[what a viewer is allowed to know](../../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

Hooks are called with nothing useful.

## Intended behaviour

A deliberately narrow interface. **The exclusions are the point.**

The security argument in
[009](../../docs/009-what-a-viewer-is-allowed-to-know.md) has to survive a carelessly
written ruleset, so a ruleset is never in a position to break it.

### It cannot

| Cannot | Because |
| --- | --- |
| Write to any socket | It would be able to leak by being written badly. |
| Read another viewer's fog or sight | Same. |
| Change a scope's ownership | Permission is not a rules question. |
| Disable a gate in the outbound filter | The filter is the wall. |
| Reach the file system, the clock, or ambient randomness | [701](701-luajit-lives-in-the-server.md). |

It can decide **what a sheet field means**. It cannot decide **whether a socket
gets bytes.**

### It can

| Capability | Shape |
| --- | --- |
| Read the world | Positions, facings, regions, walls, kinds. Read-only, through accessors taking an index. |
| Own the sheets | [703](703-the-ruleset-owns-the-sheets.md). |
| Veto commands | [705](705-a-ruleset-may-refuse.md). |
| Request changes | Ask the server to move a thing, flip a wall's bits, set `HIDDEN`. **Requests, checked the same way a participant's are.** |
| Roll | [707](707-dice-come-from-named-streams.md). |
| Answer `may_know` | [706](706-what-a-viewer-may-know.md). |

### Requests, not writes

A ruleset asking to move a body goes through the same collision resolution a
player's command does. It does not get to place things through walls, and it does
not get a second movement path.

That matters more than it sounds: a ruleset that could write positions directly
would be a second way for a body to end up somewhere, and the two would disagree
about walls within a week.

## Suggested implementation steps

1. Register accessors as C functions in the Lua state, each taking an index.
2. Bounds-check every index at the boundary and return nil for a bad one — Lua is
   the one place in this project where nil is the right answer, because a ruleset
   author is not the validator's problem.
3. Implement requests as a queue drained after the hook returns, so a ruleset
   cannot mutate the world underneath a pass that is iterating it.
4. Write the companion `.info.md`, listing every exposed function. That list is
   the sandbox's surface.
5. Test that a ruleset attempting each forbidden thing fails.
