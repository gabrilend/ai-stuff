# 111, 112, 113 — the third tongue's arithmetic — info

The eleven routines written a third time, in RISC-V's instructions, run on a
real emulated RISC-V machine through real UEFI firmware, and compared against
the first architecture's answers bit for bit.

## Running it

```
luajit src/113-test-kernels-riscv64.lua
```

## What it exports

| File | Role |
|---|---|
| `111-kernels-riscv64` | the routines, emitted into a counted program |
| `112-emit-kernel-check-riscv` | the payload that runs and compares them |
| `113-test-kernels-riscv64` | records the first tongue's answers and drives the board |

On `111`:

| Name | Meaning |
|---|---|
| `M.written` | the routines that exist here |
| `M.missing_from(names)` | what the first architecture has that this does not, worked out |
| `M.emit(p, names, options)` | lay them into a program being built |

## Why this file is built and not written

The other two tongues are held as assembler text, because their assemblers
finish branch arithmetic themselves. This one's does not. With relaxation and
compressed instructions both switched off, a conditional branch to a label in
the same file **still** leaves a relocation behind, and the extracted bytes
encode a branch to the instruction's own address. With no linker, every loop
becomes a silent infinite one — no fault, no message, a machine that says its
first mark and spins.

So every routine emits into the two-pass word emitter (`054`), which counts
the distances itself and writes finished instructions. That is why the tool
was built before the port, and why the routines here cannot be pasted in as
text: the emitter has to see every instruction to count.

`113` checks this rather than trusting it — a payload with any relocation left
in it is refused before the machine is booted.

## What this architecture does not have

Measured, not assumed. A bare probe that configures a vector register and then
says so gets no further on the `rv64` processor this project's RISC-V board
names. Where the hardware does exist, the same probe still fails until a
machine-mode control register enables the vector unit — a privilege question
rather than an instruction-set one, depending on what level the firmware hands
over at, and the three firmwares this project knows already hand over three
different ways.

So the fast matrix product keeps its four totals in **ordinary floating
registers**. Same second specification, same lane assignment, same final
combining order, so it still agrees with the first architecture's fast kernel
bit for bit — and it needs no extension, no privilege, and no negotiation with
firmware. A genuinely vectorised one can follow, for chips that have the
hardware, as a fourth kernel rather than a replacement.

## What the calling convention costs here

Integer arguments in `a0` onward, floating ones in `fa0` onward. `t0`–`t6` and
`ft0`–`ft11` may be destroyed by anything; `s0`–`s11` and `fs0`–`fs11` must be
given back. Every routine uses only the first kind, **except** the softmax and
the gate — both call the exponential, so both keep what must outlive the call
in the second kind, including the return address. Losing that one is not a
wrong answer but a machine that never comes back.

This architecture also has no floating condition flags. The other two compare
and branch on the comparison; here a comparison writes a one or a zero into an
ordinary register and the branch tests that. Same meaning, including for a
value that is not a number.

## What `054` gained

A call. The encoder always took a link register and the method hard-coded it
away, because when the tool was written a payload was one straight run of code
with nothing to call. An engine is mostly subroutines, so `:call` now emits
`jal ra`. Returning is still spelled out as `jalr zero, 0(ra)`, because a
pseudo-instruction whose expansion the tool has not checked is exactly what
the byte counting cannot survive.

Also `:word`, for four bytes of data rather than an instruction — separate from
`:op` because passing data through the instruction method counts correctly and
reads as a lie.

## What it cost to get right

**The firmware talks too, and it talks first.** This is the board with USB
storage attached — deliberately, as the most demanding of the three — and
while enumerating it the firmware prints `device is of 3 speed`. A search of
the log for "of" followed by a number found that, eleven hundred lines before
the payload said anything, and reported the machine as having compared three
values when it had compared two hundred and seventy-nine. Every answer was
right and the test said the port was broken.

The reading now starts after the payload's own header and requires each mark
to begin a line. The same guard was added to both ARM tests, which do not
happen to trip it — which is exactly why it belongs there too.

That is the second time this project has been misled by a tool reading a log
rather than by anything in the log, and it is worth more than the defect: a
tool that answers confidently is worth checking before the thing it reports on.

## Result on 2026-08-03

8 of 8. All 279 matrix values and all 133 normalisation values agree with the
first architecture bit for bit, including the exponential — which is a
polynomial here rather than a borrowed library, and is therefore comparable at
all — and including the softmax and the gate that call it.

## What is not covered

A whole forward pass on this architecture. Each routine agrees alone; nothing
yet conducts them together here, and both other architectures learned that a
piece can be right by itself and be handed the wrong thing by the piece before
it. The conducting for this tongue is the next piece of `401`.

## Related

`054-riscv-words` — the emitter this port cannot be written without.
`043-emit-kernels`, `099-kernels-aarch64` — the same routines in the other two.
`047-reference-exp` — the specification the exponential is built from.
