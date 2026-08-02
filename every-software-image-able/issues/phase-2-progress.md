# Phase 2 — The hands

**Goal.** Thinking that can touch the machine. Memory, ports, storage, a console,
a status, and — the one that matters most — running code it has just written.

A machine that can think but not act has nothing to be instructed about, which is
why this comes before the words.

## Issues

| | | Status |
|---|---|---|
| `201` | The shape of a tool call | not started |
| `202` | Say something | not started |
| `203` | Touch memory | not started |
| `204` | Run what it wrote | not started |
| `205` | Touch the hardware | not started |
| `206` | Keep something | not started |
| `207` | Emit a status | not started |

## Where the risk is

`204`, and specifically its fourth step. Code written by a model will sometimes
loop forever, and without a way to regain control the first bad function ends the
machine — so whatever the board offers for taking control back has to be working
before this hand is offered at all.

`205` and `206` land together or not at all: the discipline that makes hardware
exploration survivable depends on writing a note first, and the note needs
storage.

## Demo

The machine narrating its own startup over the serial port, then being asked for
something it has to write and run in order to answer.
