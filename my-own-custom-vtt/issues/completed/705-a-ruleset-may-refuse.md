# 705 -- A ruleset may refuse

**Phase:** 7, the rules layer
**Blocked by:** [704](704-the-narrow-window-on-the-world.md)
**Blocks:** [709](709-the-phase-seven-demo.md)
**Documents:** [commands enter through one door](../../docs/010-commands-enter-through-one-door.md)
**Open questions:** [7.1](../../docs/016-open-questions.md) — an error mid-tick.

## Current behaviour

The gauntlet has five gates and a comment where the sixth belongs.

## Intended behaviour

Gate 6. The last one, and the only one that can say anything about the game.

Where "it is not your turn" lives, and "you are paralysed", and "that is out of
range". **The server has no opinion on any of these and does not need one.**

### The refusal is a sentence the ruleset writes

Every other gate has a reason from a fixed table. This one returns a string,
because the reasons are as varied as games are.

That means the wire has to carry text for this gate where the others carry a
number — worth doing rather than forcing rulesets to pick from a list the server
invented, which would be the server having opinions by the back door.

### An error is not a refusal

A ruleset that raises an error has not refused the command; it has failed. Those
are different and must look different.

The whole argument for embedding Lua rather than compiling rules in is that
somebody's homebrew should not take down the table. So:

- The offending hook is abandoned. Its half-applied requests are **discarded**,
  not partly honoured — a request queue drained after the hook returns makes that
  free, which is one of the reasons it is a queue.
- The command is refused, with a sentence saying the ruleset failed rather than
  pretending it declined.
- The error goes somewhere a person will read.

**Which person is not settled** ([7.1](../../docs/016-open-questions.md)). A GM
plausibly; everyone plausibly; a log file plausibly. Send it to whoever issued the
command, because they are certainly interested, and leave the question open.

### Repeated failure

A hook that fails every beat will fill a log and drown the session. Count
failures per hook; past a threshold, stop calling it and say so once, loudly. A
ruleset that is broken should be visibly broken rather than continuously noisy.

## Suggested implementation steps

1. Call `on_command` in a protected call, always.
2. Distinguish "returned false with a reason" from "raised an error".
3. Discard the request queue on error.
4. Add a refusal reason and a text-carrying wire form.
5. Count and cap repeated failures per hook.
6. Write the companion `.info.md`.
7. Test: a permit, a refusal with a sentence, an error, an error every beat.
