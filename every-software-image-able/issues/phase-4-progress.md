# Phase 4 — Three tongues

**Goal.** One chip that runs on the machines people actually have. The engine
written for each assembly language in modern use, and the small piece of code
that picks between them at power-on.

Writing the same program three times is the price of not having a compiler. It is
paid once, by people, before any of these machines exist.

## Issues

| | | Status |
|---|---|---|
| `401` | The second and third tongues | not started |
| `402` | Waking on the right foot | not started |

## Where the risk is

`401` is large but not uncertain — the shape is known by then and the reference
fixture from `103` says when each port is right.

`402` is tiny and unforgiving. Starting the wrong engine executes nonsense as
instructions, which is the least debuggable failure available, so an unrecognised
processor must stop and say so rather than guess.

The open case: a processor outside the three. Either an engine for it is bundled
before flashing or it is worked out on arrival, and that is the one situation
where the seed is not self-sufficient.

## Demo

The same measurement from `106` run across all three architectures, side by side,
from one recipe.
