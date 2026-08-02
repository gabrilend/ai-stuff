# Phase 7 — The proving ground

**Goal.** Develop the seed without a computer in front of you, and test the one
thing that cannot be tested safely on real hardware.

**The phase is complete, 2026-08-02**, except for the one ticket that is not
meant to complete. Six emulated boards, devices that can be destroyed
permanently, code the model wrote made inspectable from outside, and a way to
cut the power at any chosen instant.

## Why it is numbered last and built first

Phases 1 through 6 produce things that go onto the chip or make the chip. Nothing
in phase 7 ever ships. That is what the number means here — not "do this
later," since in practice `701` is the first ticket anyone should finish.

## Issues

| | | Status |
|---|---|---|
| `701` | Run it with no computer | **completed** — six boards across three architectures, three of them booting real firmware; screenshots, memory sizes, and a processor override |
| `702` | Devices that can die — the parent of the two below | **completed** — the discipline is now testable in both directions |
| `702a` | Trap registers | **completed** — 9 of 9 with halt and count on all three architectures |
| `702b` | Devices that die realistically | **completed** — death as absence, surviving a power cycle, and arriving late |
| `703` | Watch what it wrote | **completed** — the machine's own bookkeeping published where a tool outside can walk it, and an address turned into a place by name |
| `704` | Cut the power on purpose | **completed** — bisected, with every band found rather than the first, and what the sampling could hide said out loud |
| `705` | What the emulator lies about | **open, and stays open** — fifteen entries, each with a price |

## Where the risk was, and what it turned out to be

`702`, as expected, and it was a risk of omission rather than of difficulty.
Emulated devices ignore the writes that destroy real ones, so without this the
exploration discipline was an intention with no failing test attached.

It is now testable in both directions, which is what was actually missing: a
machine that follows the discipline never reaches the fatal register and the
part lives; one that opens it and is wrong about what it does kills the part
for good, and the note it was made to write first survives to be read.

`702a` was cheap and existed within a day of `701`, as predicted. The one
thing to get right in it — that the halt stops the emulator rather than
raising something the machine can see — held.

## What `705` is for, and why it does not close

It is a list that grows every time the board disagrees with the emulator, and
marking it done would claim the disagreements had stopped. It is correct when
it is current, not when it is finished.

Each entry carries what it cost, because a list of differences is interesting
and a list with prices attached is the argument for how often to stop
developing against emulation and go put something on a card.

The newest entry is from `402`: **the emulated processor is not the host's
processor.** It presents its own synthetic part, so a detection cannot be
checked against the host — it has to be checked against a second emulated
processor, and required to disagree.

## What this phase deliberately cannot do

Prove that a machine can work out what happened to a part that stopped
answering. It cannot, and no version of this can be built where it can: a
destroyed device, a busy one and an unpowered one are indistinguishable from
inside. `docs/003a` names that as honestly hard, and `702b` is that hardness
made testable rather than argued about.

And these are all described devices. A real board is full of parts nobody
wrote down, and a machine exploring one of those passes everything here while
destroying hardware. That gap is in `notes/023`, unpaid, and it will be paid
at first light in parts.
