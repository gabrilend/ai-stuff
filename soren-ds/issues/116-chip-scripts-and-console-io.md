# 116 — chip-scripts: an interactive-tool category, and the console I/O it stands on

A new category of *thing* beside the probe battery. Probes (110i/110n) are
**fire-and-log**: a tiny declarative script, baked into a `--debug` image,
swept at boot, verdict machine-readable off the SD log. A whole class of
bring-up work does not fit that shape — anything whose verdict is a *human's*
("yes I felt the motor"), or that needs a person to *choose* what runs next.
That is a menu, a prompt, a keypress; declarative fire-and-log cannot express
it. This issue introduces **chip-scripts — "chips" for short**: hand-written
interactive C utilities that share the underlying drivers with the probe
engine but nothing else, and it brings up the one primitive they all need
first — a **console read path**, so a chip can ask a question and hear the
answer.

Two chips motivate the category (each its own issue):

- the **I/O device validation utility** (issue 115) — drive a device, ask
  "did you observe it?"; the first chip built here,
- a **probe-selector** (later) — a menu of the compiled-in probes that arms
  the chosen ones and `run_probes()` them on demand, instead of the boot
  sweep deciding for you.

Both are menus over a console. Neither can exist until the console can be
*read*, which today it cannot.

## Current behavior

**The console is write-only.** `debug_write` (011-cdc-acm.c) pushes bytes to
the host over the CDC-ACM bulk-IN endpoint and fans the same text to the
SD-backed log, so the kernel can *narrate*. But the reverse direction is
dead: `cdc_acm_init` configures and enables the bulk-**OUT** endpoint
(`EP_BULK_OUT`, host→device) in `DALEPENA`, yet nothing ever posts a receive
TRB on it or reads what the host typed. The hardware path exists; the
software to pull a byte off it does not. There is no `console_getchar`, no
way for kernel code to block on "what did the developer press."

**There is no interactive-tool category.** Every diagnostic today is a probe:
a declarative script run without a human in the loop. The probe interpreter
(`run_line` in 019-probe-engine.c) has no verb for "print a menu," "read a
key," or "branch on the answer," and deliberately so — "no arithmetic, no
variables, no control flow. Anything more complex belongs in C." That C home
does not yet exist. Issue 115's utility has nowhere to live and no menu to
live in.

## Intended behavior

### 1. A console that reads (the foundation)

A host→device read path in the CDC-ACM layer, the mirror image of
`debug_write`:

- `console_getchar()` — block until one byte arrives from the host (with the
  same generous loop budget `debug_write` uses, so a disconnected host cannot
  hang the kernel forever), and return it; return a sentinel on timeout.
- `console_read(buf, max)` — fill a small buffer up to a newline or `max`,
  for reading a whole typed line where a chip wants more than a keypress.

Mechanically this posts a Normal TRB on `EP_BULK_OUT` pointing at a receive
buffer, rings the doorbell (`DEPSTRTXFER`), and waits for the
transfer-complete event on that endpoint — exactly the `debug_write`
machinery, one endpoint over and one direction flipped. It reuses the same
event-ring watch (`wait_for_bulk_in_complete`'s pattern, generalised to name
the endpoint it waits on).

The read path is a *console* feature, not a chip feature — the
probe-selector chip needs it just as much as the validation chip, and a
future USB command shell would too. It lives with the other console code in
011, not in the chips file.

### 2. The chips category (a new file, `020-chips.c`)

A `--debug`-only file (wholly `#ifdef SOREN_DEBUG`, so a production build
compiles it to an empty object exactly as 019 does — the Makefile globs every
`src/*.c`, so the guard is what keeps chips out of a shipped image). It holds:

- **a menu primitive** — given a title and a list of labelled options, print
  them numbered over `debug_write`, read a selection with `console_getchar`,
  echo the choice back so the developer sees what registered, and return the
  chosen index (or a "quit" sentinel). This *is* the proof that I/O works:
  print, read, echo, branch.
- **a chip registry** — a small static table of `{ name, description,
  run_fn }`, the interactive analogue of `builtin_probes[]`. Unlike probes,
  chips are hand-written C, not generated from `input/`, so the table is a
  literal in the source, not a `#include` of a baked fragment.
- **a launcher — `run_chips()`** — a top-level menu of the registered chips;
  pick one, it runs, you return to the menu. This is the entry point a button
  combo or a USB console will call. **It is dormant: nothing in `kernel_main`
  calls it yet** (issue 115: "we won't want it enabled just yet"). Built,
  linked, compile-verified — but off the boot path until we choose to wire a
  trigger to it.

### 3. Why chips are C, not an extended probe DSL

The probe DSL was kept "deliberately tiny and dumb" on purpose. Growing it an
`ASK`/`MENU`/`IF` vocabulary would drag control flow, a value stack, and
branching into an interpreter whose whole virtue is having none of those. A
chip is a C function; it gets loops, `switch`, and the console read for free,
and it calls the very same driver routines the probes' `CALL` targets do. The
category boundary is the point: **probes are data, chips are code**, and they
meet only at the drivers beneath both.

## Suggested implementation steps

1. Write this issue (done) before code.
2. **Console read** (011-cdc-acm.c): allocate a bulk-OUT receive TRB + buffer
   in `cdc_acm_init`; add `console_getchar` / `console_read`; generalise the
   event-ring wait to take the endpoint it watches for. Verify the write path
   still builds and behaves.
3. **Chips file** (`020-chips.c`, `#ifdef SOREN_DEBUG`): the menu primitive,
   the `{name, description, run_fn}` registry, and the dormant `run_chips()`.
   Bump `.file-index-counter` to 20.
4. **First chip** = the I/O validation utility (issue 115): its device-test
   menu, with the rumble test (PWM3 @ `0xFE700020`) as the first reachable
   device. Register it in the table.
5. **Do not** wire `run_chips()` into `kernel_main`. Leave a comment at the
   boot site naming the seam where a trigger will later call it.
6. Datapath doc (`docs/026-chip-scripts.md`) + table-of-contents entry.

## Related documents and tools

- `src/011-cdc-acm.c` — `debug_write` and the DWC3 bulk-endpoint machinery
  the console read path mirrors; `EP_BULK_OUT` is already configured here.
- `src/019-probe-engine.c` — the fire-and-log half; `run_probes`/`probe_arm`
  (110n) are what the future probe-selector chip drives. Chips sit beside this
  file, sharing only the drivers both call.
- `src/003-pwm.c` — `led_pwm_init` / `pwm_channel_setup`: the PWM-block
  bring-up pattern the rumble test reuses on the PWM3 block.
- `issues/115-io-device-validation-utility.md` — the first chip's spec.
- `issues/110n-callable-run-probes-and-runflags.md` — the callable probe
  runner the probe-selector chip will menu over.
- The board device tree (`libs/sd-image-parts/rk3568-anbernic-rg-ds.dtb`) —
  confirms `pwm@fe700020` (alias `pwm14`) is the rumble PWM.

## Blocked by

Nothing to start — the console read path is buildable now (the bulk-OUT
endpoint is already up), and the menu primitive needs only it. Individual
chips are gated on their own drivers (issue 115 tracks the validation chip's
per-device gates; the probe-selector needs only 110n, already in place).
