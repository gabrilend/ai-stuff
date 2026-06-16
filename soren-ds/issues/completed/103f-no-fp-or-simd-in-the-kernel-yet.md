# 103f — Kernel does not use the chip's floating-point and SIMD unit yet

## Current behavior

The compiler is told, through a `-mgeneral-regs-only` flag
added to the kernel's CFLAGS, that it must not emit any
instruction that touches the chip's 128-bit-wide
floating-point and SIMD register file. The kernel's binaries
contain only instructions that operate on the integer
register file. The chip's floating-point / SIMD unit stays
disabled at the hardware level (the architecture's reset
default), the kernel never executes an instruction that
would trap on touching it, and the C language's `float` and
`double` types fail to compile if any code tries to use
them.

The flag is a build-system change rather than a kernel-code
change. The kernel source contains no floating-point math;
the flag exists to stop the compiler's *optimizer* from
opportunistically using the wide register file as a faster
path for plain integer work — memory copies, struct
initializations, bulk zeroing — even when the C source asks
for nothing of the kind. Before the flag was added, the
allocator's self-test (the first thing `kernel_main` calls
after the LED layer's stage signal) hit a compiler-emitted
SIMD instruction immediately, the chip trapped, the
bootloader's exception handler reset the system, and the
cycle repeated forever. The flag stops the optimizer from
reaching for the wide registers in the first place.

## Why this disposition and not the alternatives

Three positions a kernel can take with respect to the
floating-point / SIMD register file:

- *Disabled entirely.* The hardware unit stays off, the
  compiler emits no instructions that touch it, threads have
  no FP/SIMD state to save or restore on context switch.
  This is the position this issue picks for phase 1.
- *Enabled, eager save.* The hardware unit is on, threads
  can use floating-point and SIMD freely, the scheduler
  saves and restores all 512 bytes of the unit's register
  file on every context switch. Costs cycles on every yield
  in exchange for letting any thread use the unit
  unconditionally.
- *Enabled, lazy save.* The hardware unit is on, but the
  scheduler marks the register file "untouched" on each new
  thread. The first floating-point / SIMD instruction the
  thread executes traps; the trap handler saves the
  previous thread's state, clears the mark, and re-runs the
  instruction. Threads that never use the unit pay zero
  save / restore cost; threads that do pay the save once.

Phase 1 has no threading system — only one core is
running, only one thread of execution exists, no context
switch ever happens. There is no scheduler to host either
save policy, and no FP/SIMD use anywhere in the kernel that
would justify enabling the unit. Disabled entirely is the
simplest position that produces a working kernel today.

Soramech is the threading system phase 2 brings up. When
soramech's scheduler is being designed, this decision comes
back on the table — at that point the kernel has the
machinery a save-and-restore policy needs to live in, and
the question becomes which policy. The choice locked in for
soramech's design is the eager-save policy: every context
switch saves and restores the full register file
unconditionally, no trap-driven fixup path, predictable
scheduler latency. Lazy save remains an optimization to
revisit later if profile data shows most threads never
touch the unit — the trade-off is throughput against the
predictable timing eager save provides.

## What this issue does not do

- *Re-enable the floating-point / SIMD unit at the hardware
  level.* The unit stays disabled at the chip's reset
  default. No control-register write turns it on. Issue
  201's family — soramech bring-up — is where the
  enable-and-save-and-restore work lives.
- *Provide fixed-point math primitives.* Phase 1 does not
  need fractional values yet. The choice to use fixed-point
  rather than floating-point when the need arises is a
  later decision; this issue only makes sure the compiler
  does not put floating-point instructions into the binary
  before then.
- *Strip the existing kernel of any floating-point types.*
  There are none; the current source is integer-only. The
  flag the issue adds means future code that introduces
  floating-point will fail to compile until the soramech
  bring-up issue lifts the restriction. That is the
  intended pressure direction.

## Why floating-point and SIMD share one hardware unit on this chip

Architectural quirk worth recording in one place. The
aarch64 instruction set's wide-register file is a single
hardware unit that holds 32 registers of 128 bits each. The
same registers can be used for floating-point scalar math
(one register holding one 64-bit double or one 32-bit float)
or for SIMD lane math (one register holding two 64-bit
integers, or four 32-bit integers, or eight 16-bit integers,
or sixteen 8-bit integers, with one instruction operating on
every lane in parallel). One control bit at the CPU's
exception level enables or disables the whole unit; there
is no way to have floating-point on and SIMD off, or vice
versa.

So "disable floating-point" on this architecture means
"disable the wide-register file entirely," which catches
both kinds of use. The compiler's `-mgeneral-regs-only` flag
is the language-side name for that hardware-side reality —
the compiler refrains from emitting any instruction that
would touch the unit, regardless of whether the use is
floating-point or SIMD-integer.

## Implementation steps

1. Add `-mgeneral-regs-only` to the kernel's CFLAGS in
   `Makefile`. The flag goes alongside the existing
   `-ffreestanding`, `-nostdlib`, `-nostartfiles`, and
   `-fno-builtin`.
2. Rebuild the kernel and confirm by disassembly that no
   floating-point or SIMD instruction (any `v`/`q`/`d`/`s`/
   `b`/`h` register reference, any `movi`/`fmov`/`fadd`/etc.
   mnemonic) appears anywhere in the resulting binary.
3. Confirm by build that any code path which would have
   used a `float` or `double` type now fails to compile —
   the language-side enforcement falls out of the
   hardware-side disable for free.

## Related documents

- `notes/safety/000-bricking-and-recovery.md` — the
  exception-trap behavior that this flag eliminates. The
  bootloader's exception handler resetting the system on
  a SIMD trap is now a path the kernel cannot trigger.
- *(future)* `docs/soramech-design.md` — the issue file
  that brings the wide-register file back online will
  document the save / restore mechanism, with this issue
  as a reference for why the unit is off in the first
  place.

## Blocked by

103 (the build system this issue extends), 103d (the load-
address fix, without which the kernel did not get far enough
to even reach the SIMD trap, so the trap's role in the
"no LEDs" symptom was masked by upstream load-address
issues).

## Blocks

The allocator self-test from issue 108 actually completing
on hardware (the first SIMD instruction the optimizer
emitted lived inside it). Every phase 1 issue downstream of
the allocator — every bring-up step the kernel performs
after `STAGE_KERNEL_MAIN` — depends on the trap not firing.

## Parent

103.
