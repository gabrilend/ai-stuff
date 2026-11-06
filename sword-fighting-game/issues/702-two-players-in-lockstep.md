# 702 — Two Players In Lockstep

| | |
| --- | --- |
| Phase | 7 — Distance |
| Blocked by | 701 |
| Blocks | none |
| Files | (planned) `src/032-lockstep.lua` |

## Current behavior

One person plays against minds.

## Intended behavior

Two copies of the game share a seed and send each other only their
tick-tagged intents and commands over a socket (the engine ships LuaSocket).
Because a battle is decided entirely by its seed and its inputs, both copies
compute the same battle; each runs a configured number of ticks behind the
newest tick both inputs have arrived for. A checksum of the battle state is
exchanged every second; a mismatch stops both with a message naming the tick,
rather than letting two different battles carry on.

## Suggested implementation steps

1. Host and join options; a handshake carrying seed and catalogue checksum.
2. Input delay buffer; checksum exchange.

## Open questions

- Is the second player a second contingent's commander (versus), or a second
  soldier on the same side (co-operative)?
