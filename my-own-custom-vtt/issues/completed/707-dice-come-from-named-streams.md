# 707 -- Dice come from named streams

**Phase:** 7, the rules layer
**Blocked by:** [704](704-the-narrow-window-on-the-world.md)
**Blocks:** [709](709-the-phase-seven-demo.md)
**Documents:** [the rules layer](../../docs/011-the-rules-layer.md)

## Current behaviour

`047-streams` exists, is tested, and nothing outside the simulation uses it.
`math.random` has been removed from the sandbox, so a ruleset currently has no
randomness at all.

## Intended behaviour

A ruleset asks for a stream by name and draws from it.

```lua
local attack = vtt.stream("attack")
local roll = attack:between(1, 20)
```

### A roll is not a server concept

The server has streams; the ruleset has dice. `"3d6+2"` is a string the **ruleset**
parses.

That is right for a system-agnostic tabletop: dice pools, exploding dice,
roll-and-keep, and card draws are all the same shape to the server, which is to
say invisible.

### What the server does guarantee

A roll is **witnessed**. It happened on the host's machine, from a stream nobody
at the table controls, and it is in the command log.

**Nobody can reroll a bad result by refreshing their browser**, because the roll
was never on their machine. That is worth more than any amount of dice
presentation.

### Named, for the reason phase 3 established

Adding a draw to `"attack"` leaves `"wandering-monsters"` byte-identical. Without
that, a ruleset that starts checking one extra condition changes what monsters
wander for the rest of the session, and a written-down seed stops meaning
anything the moment anybody edits anything.

### And the positions are already snapshotted

Phase 3 put stream positions in the rollback snapshot, so a retconned turn rolls
the same dice. That was built before there was anything to roll — this is the
caller it was waiting for.

## Suggested implementation steps

1. Expose `vtt.stream(name)` returning a handle.
2. Handles carry the stream index, not the registry — a ruleset holding a stale
   handle across a reload should fail loudly rather than draw from whatever now
   occupies that slot.
3. Offer `:next()`, `:below(n)`, `:between(low, high)`. Nothing else: a ruleset
   wanting a normal distribution can build one, and the server should not have
   opinions about distributions.
4. Refuse an unknown or over-long name by name, as `stream_named` already does.
5. Write the companion `.info.md`.
6. Test: two rulesets with the same seed and the same names roll identically; a
   rollback replays the same rolls; adding a draw in one stream does not disturb
   another.
