# 021-trap-run — info

Arms the forbidden registers as landmines and runs a machine over them. If it
writes where issue 003a says it must never write, everything stops and the
record names the register, the value, and where the machine was standing.

## Invocation

```
luajit src/021-trap-run.lua <board> --payload FILE [--mode halt|count]
                            [--seconds N] [--dir ROOT]
```

Exit status is zero only for a run that proved something *and* proved it good.
Inconclusive counts as failure: a test that cannot tell you whether the
discipline held has not tested the discipline.

## The rule that makes it honest

**The halt is invisible to the machine.** Watchpoints live in a debugger
attached from outside; the guest is not interrupted, receives no exception,
and cannot notice. A trap the machine could see would teach it that touching a
fatal register produces immediate survivable feedback — the opposite of what
hardware teaches, where there is no feedback at all and the part is gone. A
trap is an assertion about *us*, not a signal in the machine's world.

Watchpoints are set on writes only. Reading a forbidden register is legal and
is exactly how a description gets confirmed (issue 302).

## The four results

| Result | What it means |
|---|---|
| `clean` | the machine ran, spoke, and wrote no forbidden register |
| `N forbidden writes` | caught, with register, category, mechanism, value and program counter |
| `the machine ended without the traps reporting` | a write that truly kills — see below |
| `INCONCLUSIVE` | fewer watchpoints armed than described, or the machine never spoke |

## Two things the runs taught

**A watchpoint cannot report a write that ends the machine.** Running the real
RISC-V hazard proved it: the machine powered off on the write and took the
debugger connection with it, so no watchpoint fired and the transcript showed
only a broken pipe. This is issue 003a's honestly-hard problem arriving early —
from outside, a machine destroyed by a write and a machine that merely went
away look identical. The console is the only witness, which is why every
hazard probe says what it is about to do *before* doing it: the last line
before silence is the confession.

**A run that armed nothing looks exactly like a run that caught nothing.** The
first x86 attempt reported `clean` while having connected to nothing at all —
the debugger had been told the wrong architecture and rejected the target.
Hence the arming count and the silence check, and hence `INCONCLUSIVE` being a
failure rather than a shrug.

The architecture to give the debugger is the *processor's*, not the mode the
code runs in: an x86 boot sector runs in 16-bit real mode on a processor that
reports itself as 64-bit, and saying `i8086` makes the debugger refuse the
connection.
