# 012 — Datapath: The Proving Ground

How the seed is tested without a computer, and what testing that way cannot tell
you.

## Three things called a virtual machine

The term covers three unrelated mechanisms, and only one of them is wanted here.

| | What it actually does | Needs an operating system inside it? |
|---|---|---|
| A container | Shares the host's kernel, isolating processes from each other | Yes — it *is* the host's operating system, partitioned |
| A language machine | Runs bytecode through a dispatch loop | No, but it runs programs rather than computers |
| **A hardware emulator** | Pretends to be a processor, memory, a bus and devices | **No** |

The third is what this project needs, and the important property is that **it does
not emulate operating system calls.** It emulates the hardware underneath them.
There is no guest operating system because there is nothing for one to be — the
emulator hands the boot code a processor, a memory map, a serial port and a bus,
exactly as a board would, and whatever runs on it is on its own.

That is how every kernel ever written was developed, and it is why nothing needs
to be written from scratch here.

Note the collision: `002` describes the machine building a bytecode machine —
the middle row of that table. It is a different thing wearing the same words, and
it runs inside the third.

## What the emulator provides

Everything the bootstrap in `003` expects to find:

```
a processor of a chosen architecture   all three targets, one tool
firmware that hands over               and a memory map to read
a serial port                          wired to the terminal you launched it from
storage                                a file on the host, presented as a device
a bus with devices on it               enumerable exactly as in 003 step two
```

Which means the whole of phase 2 is testable with no hardware in the building.
`202` (say something) works the first time it is tried, because the emulated
serial port is the terminal. `206` (keep something) works against a file. `205`
(touch the hardware) has real devices to enumerate.

Three further capabilities matter more here than they would in an ordinary
project:

**A debugger attached from outside.** The emulator can stop the machine and let
you read its registers and memory from another program. This is the only way to
debug assembly a model wrote — there are no symbols, no source, and nothing to
print with until `202` exists.

**Snapshots.** The machine's state can be saved and restored exactly. Which makes
`602`'s hardest test — pull the power at a moment of your choosing, during the
window where the machine exists in two places or neither — repeatable rather than
lucky. You can cut power at every instruction in that window, thousands of times,
and find out how bad the one unhelpable failure actually is.

**Recorded and replayed execution.** The emulator can record everything
non-deterministic and replay it identically. This is `006`'s replay mechanism
provided at the hardware level, and it can be used to check that the machine's own
version of the same idea agrees with it.

## What it cannot tell you, and this is the important half

**It will not tell you that a probe destroyed something.** An emulated device
ignores a write that would kill real silicon. Voltage registers, clock dividers,
thermal limits, non-volatile configuration — write anything to any of them and the
emulator carries on.

So the one part of this design where mistakes are unrecoverable (`003a`) is the
one part the emulator gives no feedback on. A machine could pass every emulated
test by exploring recklessly and then destroy the first real board it touched.

**This is what we write ourselves**, and it comes in two pieces answering two
different questions.

**Trap registers** come first, and they are cheap. Registers that do nothing
except stop everything, placed exactly where the forbidden ones sit on the real
part. A write lands, the world halts, and the record names the device, the
register, the value and the instruction.

The rule that makes them work: **the halt is invisible to the machine.** It stops
the emulator from outside rather than raising anything inside the guest. A trap
the machine can observe would teach it that touching a forbidden register produces
immediate survivable feedback — which is exactly backwards, since real hardware
gives no feedback and the part is simply gone. A machine trained against visible
traps learns to explore by trial, and the trial that matters happens once.

A trap is an assertion about *us*: did the instruction and the discipline hold? It
is not a signal in the machine's world, and if it ever fires, something upstream
is wrong.

**Devices that die realistically** come second and are much harder. Death as
absence rather than announcement; death that survives a restart; death that
arrives late, the way thermal damage does, by which time the machine is doing
something unrelated. And the three-way confusion `003a` calls honestly hard — a
destroyed part, a busy part and an unpowered part, all in one run, all looking
identical from inside.

The order matters. Testing whether a machine copes with ambiguity is only worth
doing once it has been established that it does not walk into the forbidden
registers to begin with.

**The best thing traps are good for** is the recovery test. Halt on a forbidden
write, restart from storage, and check whether the machine reads the note it left
before the attempt and declines to repeat it. That is the whole gravestone
mechanism, end to end, deterministic, repeatable as often as wanted — and on real
hardware it could only ever be tested by destroying something.

**It lies about speed.** Emulating a processor costs between ten and a hundred
times what running on it costs, so a model under emulation is glacial and the
tokens-per-second number from `106` is meaningless there. Correctness in
emulation, speed on hardware — two loops, and the second cannot be skipped.

**Its firmware is tidier than reality.** Emulated memory maps are clean; real ones
have holes, quirks, and regions that lie. "Works in the emulator" and "works on
the board" are different claims, and the gap between them is where most of first
light (`601`) will be spent.

## The two loops

```
every day        → build, run in the emulator, on all three architectures
                   correctness, behaviour, the discipline, the crash windows

less often       → put it on a card, put the card in a computer
                   speed, firmware reality, and whether any of this is true
```

The first loop is where the work happens. The second is the only one that counts.

## Open questions

- **How faithful is the dying device?** A model that stops answering is easy. One
  that reproduces the *ambiguity* — where a destroyed part, a busy part and an
  unpowered part all look identical from inside — is harder and is closer to what
  `003a` says is honestly hard.
- **Can growth be tested at all?** Phase 6 ends by leaving the machine alone to
  build for a long time. Under emulation that is a hundred times longer, which may
  put the most interesting observation out of reach until there is hardware.
- **Does the emulator's tidiness train the wrong instincts?** A machine that grows
  up in emulation learns its own hardware from a clean example, and the first
  thing it meets afterward is not clean.
