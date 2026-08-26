# 701 -- LuaJIT lives in the server

**Phase:** 7, the rules layer
**Blocked by:** phase 6 complete.
**Blocks:** everything else in phase 7.
**Documents:** [the rules layer](../docs/011-the-rules-layer.md)
**Open questions:** [7.1](../docs/016-open-questions.md) — what happens when a
ruleset raises an error mid-tick.

## Current behaviour

The gauntlet has a hole in it labelled "the ruleset". Nothing loads.

## Intended behaviour

LuaJIT compiled into the server as a library. A ruleset is a directory of Lua
files, loaded at startup the way a font is loaded.

### Why Lua, and why not the alternatives

**Not a bespoke language.** A ruleset needs tables, arithmetic, string handling,
and closures. Writing a language that has those badly is a year of work producing
something worse than what exists.

**Not C.** A ruleset is the part people are expected to write and rewrite, and a
segfault in somebody's homebrew should not take down the table.

**Not a data format.** "When this creature drops below half its hit points it
flees toward the nearest exit" is a program, and a data format that can express it
has become a programming language with an awkward syntax.

### It is not a plugin

A ruleset never executes arbitrary machine code and cannot load a shared object.
It reaches the world only through the interface in
[704](704-the-narrow-window-on-the-world.md).

### Determinism, which a ruleset can break silently

A ruleset that calls the system clock, reads `/dev/urandom`, or iterates a table
in hash order and acts on the first key destroys the replay — **quietly**, so the
divergence appears an hour in with nothing to point at.

So the sandbox removes them:

| Removed | Why |
| --- | --- |
| `os.time`, `os.clock`, `os.date` | The ruleset is given the tick number and has no access to the time of day. |
| `math.random`, `math.randomseed` | Dice come from named streams. See [707](707-dice-come-from-named-streams.md). |
| `io`, `os.execute`, `os.remove`, `dofile`, `loadfile` | A ruleset is not a program on the host's machine. |
| `require` outside the ruleset's own directory | Same. |
| `collectgarbage("collect")` at will | Not correctness, but a ruleset that stalls the beat is one nobody can diagnose. |

`pairs` is left, because removing it would make Lua unpleasant to write — but
**anything that walks a set and acts on it must walk it in index order**, and the
determinism harness is what catches a ruleset that does not.

## Suggested implementation steps

1. Link LuaJIT via `pkg-config`. Record in the architecture document that the
   system library was used deliberately rather than vendored.
2. Create the state, open only the libraries a ruleset may have, and remove the
   entries above by name.
3. Load a directory of `.lua` files in numeric order — same discipline as the
   source: reading from the lowest number is the story.
4. A syntax error names the file and the line and **refuses to start**. A server
   running with half a ruleset is worse than one that would not start.
5. Write the companion `.info.md`, listing exactly what was removed. That list is
   the sandbox's specification.
6. Test that each removed name is absent, and that a ruleset trying to reach one
   fails rather than finding a stub.
