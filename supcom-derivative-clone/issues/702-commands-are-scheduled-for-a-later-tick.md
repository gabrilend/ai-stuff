# 702 — Commands are scheduled for a later tick

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 701 |
| Blocks | 703, 707 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | F3 |

## Current behavior

Nothing. The command door (issue 108) applies a command at the tick it is stamped
with and has no opinion about how far ahead that tick is. On a single machine
the viewer stamps a command for the next tick and the door applies it there.
`tests/025-other-players.lua` looks for `schedule` on the `lockstep` stem and
asserts that a command stamped for a tick that has already run is refused.

## Intended behavior

**A command issued at tick T is stamped for T plus the delay and sent to every
peer at once.** `schedule(command, tick, delay)` does three things in one
motion: writes the stamp, appends the command to the local batch for that tick,
and hands the batch to the transport. Nothing is held back to be sent later; the
whole point of the delay is that the batch has the delay's worth of ticks to
arrive before anybody needs it.

The door grows one rule: **a command for a tick that has already run is refused,
by name.** On one machine the delay is one tick and the refusal never fires. On
the wire it is what turns a late packet into a diagnosable event — the refusal
names the command, its stamp, and the current tick — instead of a silent fork
where one machine applied something the others did not.

The delay is a catalogue number in ticks. The working ruling is five on a
computer, which at the working tick rate is half a second, and the player
already expects a placement to take effect later than the press. The handheld's
delay is pending its measured latency (issue 707).

Batches for ticks with no commands are still sent, every tick. That is the
cost of the model and it is small: a header and a zero.

## Suggested implementation steps

1. Add `schedule` to the `lockstep` stem. Arguments: the command record, the
   current tick, the delay. Returns the stamped tick.
2. Write the local batch table: for each future tick, the commands stamped for
   it. A batch is sealed and sent when the local tick advances past its stamp
   minus the delay — which is to say, immediately, since a batch for T is
   complete the moment T minus the delay has run.
3. Add the refusal to the door in issue 108's module: a stamp at or below the
   tick already run returns a named refusal through the same path every other
   refusal uses.
4. Write the empty-batch send: every tick, after the local commands for that
   tick are sealed, the batch goes out even if its count is zero.
5. Read the delay from the catalogue at match open; the single-machine case
   passes one.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
  — the invariant that everything is queued
- `tests/025-other-players.lua`

## Still open

- **F3.** The input delay in ticks. Five on a computer is a working ruling; the
  handheld's waits on measured latency.
- Whether a viewer should show the stamped tick — "takes effect in half a second"
  — or hide it. The design's answer is that a queued command is normal here, so
  probably nothing needs showing, but a person should decide by playing.
