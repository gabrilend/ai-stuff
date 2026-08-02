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

`401`, and specifically its fast half. The plain arithmetic ports almost
mechanically; the vectorised version does not, because the three architectures'
vector instruction sets have nothing in common and RISC-V may not have one at all.
That is three pieces of work wearing one ticket number.

`402` turned out not to be what it looked like. There is no shared code that can
detect a processor and pick an engine — machine code is not portable, so the
detector would need an architecture of its own. Each firmware finds its own
payload where its convention says to look, which makes this a question of laying
the medium out rather than of dispatching at runtime.

One shape change to expect: x86 talks to devices through a separate address space
and its own instructions, while the other two are memory-mapped throughout. The
catalogue of hands is therefore not identical across architectures, which the
instruction must not assume away.

The open case: a processor outside the three. Either an engine for it is bundled
before flashing or it is worked out on arrival, and that is the one situation
where the seed is not self-sufficient.

## Demo

The same measurement from `106` run across all three architectures, side by side,
from one recipe.
