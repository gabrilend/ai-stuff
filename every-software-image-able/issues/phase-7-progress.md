# Phase 7 — The proving ground

**Goal.** Develop the seed without a computer in front of you, and test the one
thing that cannot be tested safely on real hardware.

## Why it is numbered last and built first

Phases 1 through 6 produce things that go onto the chip or make the chip. Nothing
in phase 7 ever ships. That is what the number means here — not "do this
later," since in practice `701` is the first ticket anyone should finish.

## Issues

| | | Status |
|---|---|---|
| `701` | Run it with no computer | not started |
| `702` | Devices that can die — the parent of the two below | not started |
| `702a` | Trap registers | not started |
| `702b` | Devices that die realistically | not started |
| `703` | Watch what it wrote | not started |
| `704` | Cut the power on purpose | not started |
| `705` | What the emulator lies about | not started |

## Where the risk is

`702`, and it is a risk of omission rather than of difficulty. Emulated devices
ignore the writes that destroy real ones, so without this the exploration
discipline is an intention with no failing test attached — and a machine could
pass everything by exploring recklessly, then kill the first real board it met.

It is also the only substantial thing built in this phase. The rest is
configuration of a tool that already exists.

`702a` is cheap and should exist within a day of `701`. The one thing to get right
in it is that the halt stops the emulator rather than raising anything the machine
can see — a trap it can observe teaches it that forbidden writes give immediate
survivable feedback, which is the opposite of what hardware teaches.

`705` is the ticket that never finishes, and should not be closed. It is a list
that grows every time the board disagrees with the emulator — with a price beside
each entry, since a list of differences is interesting and a list of differences
with costs attached is the argument for how often to leave the emulator.

## What changed about this phase's relationship to phase 5

An emulated machine is a board, so it gets a board description like any other and
the emulator's command line is generated from it. Which means an image for an
emulated machine is built by the same builder, from the same recipe, as one for a
real board — and `502` is under test from the first week rather than from phase 5.
The seam most likely to break first light is the one exercised most.

## Demo

A machine exploring an unknown device, under the discipline, with a running count
of parts destroyed — and the same run with the discipline switched off, for
comparison.
