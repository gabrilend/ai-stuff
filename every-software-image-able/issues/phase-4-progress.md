# Phase 4 — Three tongues

**Goal.** One chip that runs on the machines people actually have. The engine
written for each assembly language in modern use, and the small piece of code
that picks between them at power-on.

Writing the same program three times is the price of not having a compiler. It is
paid once, by people, before any of these machines exist.

## Issues

| | | Status |
|---|---|---|
| `401` | The second and third tongues | **in progress** — a whole thought is now assembly end to end on the second architecture and every score agrees with the first bit for bit, 192 of 192; the hands are not ported, and the third architecture is not begun |
| `402` | Waking on the right foot | **completed** — the selection proved on all three architectures, the within-architecture detection written and proved by booting two different processors and requiring them to disagree, 18 of 18 |

## Where the risk is

`401`, and specifically its fast half. The plain arithmetic ports almost
mechanically; the vectorised version does not, because the three architectures'
vector instruction sets have nothing in common and RISC-V may not have one at all.
That is three pieces of work wearing one ticket number.

For the second architecture that risk is now spent rather than argued about.
The fast kernel is held to the identical answer over a whole pass, not just
per call — a difference of one bit anywhere compounds through every tensor
and every layer before it reaches a score, so a whole pass is a far harder
question to ask it than any single call. It gave the same 192 scores.

The conducting turned out to be the easy half on this architecture too, for
the reason it was easy on the first: there is no floating point in it. Every
number it touches is a count or an address, so the one genuine difference
between the two — this architecture has ten registers that survive a call
where x86 has six, and therefore keeps in registers what the first tongue had
to spill to the stack — cannot change an answer.

What is left of `401` after this is the half that is not a translation at
all: the hands. x86 reaches devices through a separate address space with its
own instructions and the other two are memory-mapped throughout, so that hand
changes shape rather than detail.

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
