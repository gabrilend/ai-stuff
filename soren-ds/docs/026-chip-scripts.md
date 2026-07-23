# Chip-scripts — the interactive-tool datapath

Chip-scripts ("chips") are the interactive counterpart to the probe battery.
A **probe** (see `019-probe-engine.c`, issues 110i/110n) is *fire-and-log*: a
declarative script sweeps the hardware at boot and writes a machine-readable
verdict to the SD log, no person involved. A **chip** is the opposite shape:
hand-written interactive C that drives a device, then asks a human what
happened — the only verdict a screen, a speaker, or a motor can give. Probes
are data; chips are code; they meet only at the drivers beneath both.

This document traces the data flow. The build task and rationale live in
issues 116 (framework) and 115 (the first chip); this is the enduring map.

## Where it lives

- `src/011-cdc-acm.c` — the console, **both directions**. `debug_write`
  (out) was always here; the read path (`console_getchar`, `console_readline`)
  is the addition chips required.
- `src/020-chips.c` — the chips category: the menu primitive, the chip
  registry, the `run_chips()` launcher, and the chips themselves. Wholly
  `#ifdef SOREN_DEBUG`, so a production image carries none of it (the object
  compiles to zero bytes — the guard is what keeps it out).

## Datapath 1 — the console, both directions

Everything a chip says and hears crosses the CDC-ACM virtual serial port
(`/dev/ttyACM0` on the host) over two DWC3 bulk endpoints.

**Out (narration), the pre-existing path:**

```
chip code → debug_write(text) ─┬→ debug_log_append   → SD-backed log
                               └→ Normal TRB on EP_BULK_IN
                                  → DEPSTRTXFER doorbell
                                  → wait XferComplete  → host terminal
```

**In (the read path chips added):**

```
host keypress → EP_BULK_OUT (DMA into bulk_out_staging)
             → controller writes residual into the OUT TRB
             → console_getchar():
                  arm one Normal TRB on EP_BULK_OUT (once)
                  wait XferComplete (bounded budget)
                  bytes = requested − residual   ← read residual VOLATILE
                  hand out one byte per call, buffering the rest
             → chip code
```

Two properties matter for anyone touching this:

- **Exactly one receive transfer is ever outstanding.** A timed-out wait
  leaves the TRB armed (`rx_armed`) and the next call resumes waiting on the
  *same* transfer — never a second `DEPSTRTXFER` on an endpoint that already
  has one active, which a DWC3 rejects. `console_getchar` re-arms only after a
  completion is drained.
- **The residual is read through a `volatile` access.** `fill_trb` stores the
  request size into the TRB; the controller overwrites it by DMA on
  completion. A plain read could hand back the stale request size, so the
  read forces a fresh load. This is the one non-obvious correctness point in
  the whole path.

The bounded wait budget is the same escape hatch `debug_write` has always
used: a disconnected host makes a transfer that never completes, and the
budget keeps that from hanging the kernel.

## Datapath 2 — the menu, and a chip's verdict

`run_chips()` is a two-level menu built entirely on datapath 1:

```
run_chips()
  → chip_menu(title, options, n)     print numbered list  (debug_write)
                                     read a key           (console_getchar)
                                     echo the choice      (debug_write)
                                     return index or −1 (q/ESC)
  → chips[sel].run()                 e.g. chip_io_validation()
      → chip_menu(device tests…)     the same primitive, one level down
      → io_test_*()                  drive the device, then
        → ask_yes_no(question)       read a y/n verdict
      → "VERDICT …: PASS/FAIL"       (debug_write → SD log + host)
```

`chip_menu` and `ask_yes_no` are the whole interaction vocabulary: print
options, read a key, echo it, branch. A chip composes device drives between
them. Every verdict is a `debug_write`, so it lands in the same SD-backed log
the probes write to — a validation run leaves a record even though the
verdicts are a human's.

## The chip registry

The interactive analogue of `builtin_probes[]`. Because chips are
hand-written C (not generated from `input/` like probes), the table is a
literal in `020-chips.c`: `{ name, description, run }`. A new chip — the
probe-selector is next, a menu that arms probes and `run_probes()` them on
demand — adds a row. `run_chips()` menus over the descriptions and dispatches
through the `run` pointer.

## Dormant by design

`run_chips()` is built and linked but **not called from `kernel_main`**. It
blocks on the console for a keypress, so it belongs behind a deliberate
trigger (a button chord, a console command), not in the boot sweep. The boot
park in `002-main.c` (under `SOREN_DEBUG`, after `run_probes()`) carries a
comment marking the seam where such a trigger will hand off to it.

## Growth path

The I/O validation chip grows an entry as each device's driver lands:

- **reachable now** — the console echo self-test (validates the input path
  itself) and the rumble motor (PWM3 @ `0xFE700020`);
- **rumble is not yet a full pass** — the PWM3 controller clock-ungate,
  reset-release, and pin-mux are unresolved device-tree phandles
  (`clocks = <clk 0x160, pclk 0x15f>`, `pinctrl-0 = <0xbd>`); the drive logic
  is in place and announces the gap at runtime so "no buzz" is not read as a
  dead motor;
- **display** waits on the framebuffer (issues 111a–d);
- **audio** waits on the I2S path and the RK817 codec;
- **buttons / sticks** wait on the phase-5 input drivers.

To confirm what a given build actually compiles in, read the symbols rather
than trusting this list: `aarch64-elf-nm` on `020-chips.o` shows the chip
functions in a `--debug` build and nothing in a lean one.
