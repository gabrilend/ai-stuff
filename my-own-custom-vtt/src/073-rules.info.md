# 073-rules

The part that is allowed to have opinions. LuaJIT embedded, sandboxed, with a
deliberately narrow window on the world.

A ruleset is a directory of `.lua` files loaded in numeric order — the same
discipline as the source, so reading from the lowest number is the story.

## The exclusions are the point

The security argument has to survive a **carelessly written** ruleset, so a
ruleset is never in a position to break it. It can decide what a sheet field
*means*. It cannot decide whether a socket gets bytes.

Removed by name, and each one is a way to make a replay diverge silently or reach
off the machine:

| Removed | Why |
| --- | --- |
| `os` | The clock. A ruleset given the time of day makes a replay diverge with nothing to point at. |
| `math.random`, `math.randomseed` | Ambient randomness. Dice come from named streams. |
| `io`, `dofile`, `loadfile`, `require`, `package` | A ruleset is not a program on the host's machine. |
| `load`, `loadstring` | Arbitrary code. |
| `debug` | Reaches around everything above. |

`pairs` is **kept**, because removing it would make Lua unpleasant to write — but
anything that walks a set and acts on it must walk it in index order, and the
determinism harness is what catches a ruleset that does not.

## The window

`vtt.thing`, `vtt.thing_count`, `vtt.distance`, `vtt.region_of`,
`vtt.region_name`, `vtt.tick`, `vtt.sheet`, `vtt.move`, `vtt.set_hidden`,
`vtt.set_kind`, `vtt.stream`.

**That is the whole surface.** No socket, no fog, no scope ownership.

`vtt.thing` returns a **copy**, not a handle. A ruleset holding a reference into
the world could write through it, and then there would be two ways for a body to
end up somewhere — which would disagree about walls within a week. The copy also
omits `scope` and `sheet`: who commands a body is a permission question rules do
not get to ask.

A bad index returns **nil** — the one place in this project where nil is right,
because a ruleset author is not the validator's problem and an error at the point
of the mistake beats a silent empty record.

## Requests, not writes

`vtt.move` queues. The queue is drained **after** the hook returns, so a ruleset
cannot mutate the world underneath a pass that is iterating it — and so an
erroring hook's half-applied requests can be discarded whole.

A move goes through the ordinary order machinery, so the motion pass resolves it
against walls exactly as it would a player's. A ruleset does not get to place
things through stone.

## The hooks

`on_load`, `on_command`, `on_action`, `on_tick`, `on_region_enter`,
`on_interact`, `may_know`, `describe`.

Resolved **once at load** into registry references. Looking them up by name per
body per beat would be a string hash somebody chose to pay for. A missing hook is
not an error, and an absent one is skipped entirely rather than called and doing
nothing.

`on_action` is where a whole game lives. Everything the server does not
understand arrives there with a scope attached.

## An error is not a refusal

A ruleset that raises has **failed**, not declined, and those look different —
"you may not" and "the rules are broken" send a person to look at different
things.

After `HOOK_FAILURE_LIMIT` (8) failures a hook is abandoned and that is said once.
A ruleset that is broken should be visibly broken rather than continuously noisy.

**An abandoned veto fails open, not closed.** Failing closed would freeze a table
completely over one bad line; failing open continues the evening under no rules,
which is worse than correct and much better than stopped. It is the right trade
only because the failure was announced loudly first.

## `may_know` defaults to nothing

A ruleset with no hook sends no sheet fields. **Adding a rules layer must not
widen what is sent by default** — a system that becomes more revealing because
somebody loaded a ruleset that does not mention the subject has it backwards.

## Two things that do not work

**Sheets do not survive a rollback.** A world snapshot is a memcpy of flat
blocks; a Lua table is not. `rules_sheets_survive_rollback` returns 0 so a caller
can *say* so rather than pretend. Open question 14.1, and the largest known hole
in the project.

**This module is exempt from the build's floating-point check**, because Lua's
only number type is a double. That relocates the determinism argument rather than
holing it — a VM executing bytecode one operation at a time cannot reassociate or
fuse — but transcendentals may differ between platforms. Open question 14.2.
