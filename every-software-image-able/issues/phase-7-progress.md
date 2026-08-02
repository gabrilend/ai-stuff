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
that grows every time the board disagrees with the emulator.

## Demo

A machine exploring an unknown device, under the discipline, with a running count
of parts destroyed — and the same run with the discipline switched off, for
comparison.
