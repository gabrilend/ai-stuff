# 023 — What the emulator lies about

A living list. It never closes, and it should be added to every time a real
board disagrees with an emulated one.

**Each entry carries what it cost.** A list of differences is interesting; a
list of differences with prices attached is the argument for how often to stop
developing against emulation and go put something on a card. That argument
will otherwise get made on feeling.

Issue `705` is the blueprint for this file.

---

## Paid for already

### Traps cover only the addresses somebody wrote down

**What emulation shows.** A clean sweep of the trap matrix (`src/022`): every
forbidden register armed, every well-behaved machine cleared, every reckless
one caught.

**What is actually true.** The watchpoints are armed from a map somebody
typed. A real board is full of devices nobody described, and a machine
exploring one of those passes the entire matrix while destroying hardware.

**Cost so far.** Nothing, and that is the problem — this one has not been paid
for yet. It will be paid at first light, in parts.

**What would narrow it.** Device models rather than addresses (`702b`), and an
honest count of how much of a real board's attack surface is described.

---

### A write that ends the machine cannot be reported by a watchpoint

**What emulation shows.** Nothing. The debugger sees a broken pipe.

**What is actually true.** The machine died at that write. The reporting
channel dies with the machine, so no watchpoint fires and the transcript is
indistinguishable from a machine that merely went away.

This is `003a`'s honestly-hard problem arriving far earlier than expected —
from outside, a destroyed machine and an absent one look identical. The
console is the only witness, which is why every hazard probe now says what it
is about to do *before* doing it. The last line before silence is the
confession.

**Cost.** One run, and only because a single genuine fatal register sat in a
map otherwise full of invented ones. **A map of purely synthetic hazards would
have passed everything and taught nothing.** That is the transferable lesson:
keep at least one real danger in any set of pretend ones.

---

### The debugger wants the processor's architecture, not the code's mode

**What emulation shows.** A confident `clean` result.

**What is actually true.** The debugger had rejected the target and connected
to nothing. Zero watchpoints armed. A run that armed nothing looked exactly
like a run that caught nothing.

The x86 payload is a boot sector running in sixteen-bit real mode, on a
processor that reports itself as sixty-four-bit. Telling the debugger the
former makes it refuse the connection. **The mode the code is in and the
processor the code is on are different questions.**

**Cost.** One run, plus the fix: an arming count, a check that the machine
spoke at all, and an inconclusive verdict that counts as failure. A test that
cannot say whether the discipline held has not tested the discipline.

---

## Expected, unpaid

Written down before being met, so that meeting them is cheaper. None of these
have cost anything yet, which means none of them have been confirmed either.

| Difference | Why emulation hides it |
|---|---|
| Memory maps are tidy | Real ones have holes in awkward places, and regions that lie |
| Firmware hands over in a clean state | Interrupt state, processor mode and cache state all differ |
| Devices answer immediately and predictably | An initialisation wait that is too short passes wherever timing means nothing |
| Nothing overheats, sags, or wears out | Every slow failure mode is absent |
| Unaligned access is tolerated | Some real processors fault on it |

---

## Speed numbers do not belong here

Emulated tokens-per-second is not slow-but-indicative. It is meaningless, and
putting it in a table beside a real measurement invites somebody to compare
them. Keep those figures in their own place, marked (`106`).
