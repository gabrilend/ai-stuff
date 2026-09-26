# 200 — The laptop twin

## Current behavior

**Built.** The portable code compiles twice from one tree: the kernel's
own build picks up `src/engine/`, `src/system/` and `src/device/` with
the cross-compiler (so every build checks the portable code against the
real target's rules — no floating point, no standard library), and
`twin/Makefile` builds `src/engine/` and `src/system/` with the laptop's
compiler together with the laptop's answers in `twin/`.

| piece | where |
|---|---|
| the questions | `src/engine/025-platform.h` — cores, sleeping and waking, time, entropy, memory, the developer's line, screens, surviving a faulting box |
| the laptop's answers | `twin/026-platform-twin.c` — one thread per core, a word per core to sleep on (a kernel futex), the monotonic clock, one anonymous memory mapping, memory screens |
| the device's answers | `src/device/042-platform-device.c`, `043-cores.s`, `044-identity-map.c`, `045-compiler-support.c` — **unverified on hardware**, compiled into every image, called by nothing in the ordinary boot |
| running the engine in a laptop program | `twin/041-twin-engine.c` — cores in the background; the calling thread is the engine's "outside" owner |
| pictures of the screens | `twin/057-screens-twin.c` — PNG, one screen or both stacked as on the device |
| measurements for the documentation | `twin/046-metrics.c` — one tab-separated line per number, in `tmp/shared-memory/metrics/` |
| build variants | `debug` (fault catcher on — what the tests run), `fast` (what measurements run), `asan` (clang's address checker, blocks from the host allocator — for hunting memory bugs) |
| scripts | `scripts/test-twin` (build both variants, run every test), `scripts/ensure-tmp` (recreate the RAM tiers), `run-demo` (the phase demo picker) |

The twin is how phase 2's engine was proven: every test under
`twin/tests/` runs on it, and the endurance demo (215) runs on it. None
of that proves the chip — the device halves of 201 and 202 are written
and compile, and nobody has run them.

The one change phase 1's code received: `src/006-panic.c` now calls the
device platform first, so a box that faults under a debug build can be
returned from instead of panicking, and `src/024-display.c` publishes
which framebuffer is which screen.

## Intended behavior

**One body of portable C, compiled twice: once into the kernel image, and
once into an ordinary program on the laptop that answers the same handful of
hardware questions with the laptop's own equivalents.**

The portable code does not know which one it is in. It asks a small set of
questions through one seam — the *platform* — and each build supplies its
own answers.

| question the portable code asks | the device answers with | the twin answers with |
|---|---|---|
| how many cores, which one am I | the chip's four cores, released through the secure firmware; a per-core register holding the core's context | that many operating-system threads; a per-thread variable holding the context |
| sleep until woken | wait-for-event, with the chip's one-bit event register per core | a one-bit flag per core, and a kernel wait on it — the same "a wake that arrives before the sleep is not lost" rule |
| wake everyone | send-event | set every core's flag and wake every waiter |
| sleep until a deadline | wait-for-interrupt with the core's timer armed, interrupts masked | a timed wait on the same flag |
| what time is it | the ARM generic timer's counter | the operating system's monotonic clock |
| where is the memory | the pool from 107, below the kernel | one large anonymous mapping, the same size-shape |
| a line to the developer | the USB serial line and the SD-card log | standard output and a log under `tmp/shared-memory/` |
| a box faulted (debug build) | the exception vector returns to a snapshot taken before the call | the segmentation-fault signal returns to the same kind of snapshot |
| where pixels go | the two display controller output paths | two framebuffers of the same size and format, written out as images or shown in a window |
| where button and touch states come from | GPIO, the ADC, the touch controllers over I2C | a scripted event file, or the keyboard and mouse |
| where blocks are stored | the SD card driver | a disk-image file |
| how another device is reached | the WiFi radio in ad-hoc mode, and the USB cable | datagrams between twin processes on this machine |

**Where the code lives.** The kernel's build compiles every `.c` under
`src/`, so the split is by subdirectory:

| folder | what lives there | compiled into |
|---|---|---|
| `src/` (top level, 000–024) | phase 1's register-level drivers | the kernel only |
| `src/engine/` | phases 2 and 3: the engine and the runtime | both |
| `src/system/` | phases 4–10: filesystem, input, compositor, transport, apps | both |
| `src/device/` | the device's answers to the platform questions | the kernel only |
| `twin/` | the laptop's answers, the twin's programs, and its tests | the twin only |

Every file under `src/engine/` and `src/system/` is freestanding C: no
standard library, no floating point (the kernel is built so that any
floating-point instruction fails to compile, issue 103f), and no copying
routine it did not write itself, because the kernel has none.

**The device keeps booting exactly as it does today.** The portable code is
compiled into the kernel image so that it is checked by the real
cross-compiler on every build, but nothing in the ordinary boot path calls
it. It is switched on by building with the engine flag, which is how the
blind device halves of 201, 202 and later issues get tried on hardware
when the owner chooses to.

**What the twin proves and what it does not.** It proves the logic: a value
is never lost, doubled or torn; the map loader refuses what it should; the
drawer slides in from the correct edge; a chord of down-left and B types the
character the table says. It does not prove anything about the chip: that
the exclusive monitor arbitrates across cores, that the display controller
scans out the framebuffer, that the WiFi radio joins an ad-hoc cell. Every
issue whose device half has not run on the device says so, in its
Current behavior, with the words **unverified on hardware**.

## Suggested implementation steps

1. The platform header, `src/engine/025-platform.h` — the questions, as
   declarations only.
2. The twin's answers, `twin/026-platform-twin.c`, built on POSIX threads,
   futex-style waits and the monotonic clock.
3. The device's answers, `src/device/`, written against the phase 1 drivers
   and the device halves of 201 and 202, compiled but only called under the
   engine build flag.
4. `twin/Makefile` — compiles `src/engine/`, `src/system/` and `twin/`
   with the host compiler, `-Wall -Wextra -Werror`. The freestanding
   restrictions are checked for free by the kernel's own build, which
   compiles the same folders with the cross-compiler and the kernel's
   flags on every build — no separate pass is needed.
5. `scripts/test-twin` (build both variants, run every test) and
   `scripts/ensure-tmp` — project-root-aware, `${DIR}` at the top,
   overridable by the first argument. A separate build-only script was
   not needed: `make -C twin` is it.
6. Confirm the kernel image still builds with the cross-compiler after
   the portable folders are added. (Done; it does.)

## Open questions

- *Should the twin run the phase 1 drivers against a model of the chip's
  registers?* **Proposed answer (UNVERIFIED — not yet asked of the
  owner):** no. A register model good enough to be worth trusting is a
  second, larger project, and the thing it would test — "do we write the
  register the datasheet says" — is exactly what only the device can
  answer truthfully.
- *Is the twin a product or a tool?* **Proposed answer (UNVERIFIED):** a
  tool first, and a demonstration second. The phase demos run on it,
  because they can be run by anybody without a device, and each demo
  says plainly which of its numbers came from the twin.

### Proposed answers (UNVERIFIED — written by the builder, not yet confirmed by the owner)

1. *Model the registers?* No, as proposed above.
2. *Product or tool?* A tool first; the demos run on it and say so.
3. *(new)* **Should the engine's build flag switch the device over
   entirely?** Proposed: yes — `scripts/build --engine` should call
   `device_platform_init`, the identity map, and `platform_start_cores`
   from `kernel_main`, replacing phase 1's single-core loop. Not wired
   yet, because the first hardware run of 201 is the owner's call.

## Blocked by

Nothing.

## Blocks

201, 202, 203, 204, 205, 206.

## Related

- [001 — Architecture overview](../docs/001-architecture-overview.md), the
  C-bottom / soramech-everything-else split this seam follows
- [103f — No floating point in the kernel](completed/103f-no-fp-or-simd-in-the-kernel-yet.md),
  why the portable code is integer-only
