# 309 — Launch utility boxes

## Current behavior

The descriptor table from 208 ships with a small test library
(noop, inc, add, constants, count-down, discard) that was just
enough to write the threading-core torture test. Real maps need
more: a way to write text to the debug stream, a way to wait,
a way to deliberately fail for testing, a pseudo-random source.

## Intended behavior

Phase 3 extends 208's descriptor table with the launch utility
boxes:

- **`debug-write`** — one input, a string value. Output is a
  success bool. The function wraps the CDC-ACM `debug_write`
  from 110 and pushes the input bytes to the laptop's serial
  terminal. The output is always true for now (the CDC-ACM
  buffer never reports failure at this layer); the bool is
  there so a downstream box can chain off the write completing.
- **`timer`** — no inputs. Self-arming: the box fires once per
  configured tick interval. The configuration field on the box
  carries the interval in milliseconds and the maximum number
  of fires (or zero for unlimited). Output is the tick number,
  monotonically increasing. The cycle detector (306) recognises
  `timer` as a self-arming routing kind so self-feedback through
  a timer doesn't trip cycle detection.
- **`panic`** — one input. Always fails: the function calls the
  panic stub from 105 with a small "deliberate panic for
  testing" reason code. There is no output. This box exists so
  the torture test (211 already used a stub) and the phase 3
  demo can prove the panic path works end-to-end.
- **`random-byte`** — no inputs. Output is a single
  pseudo-random byte from the per-box-instance RNG state set up
  in 202's worker context. The function pulls one byte and
  advances the state with release ordering so concurrent calls
  on different workers see independent values without races.

Each utility box is a small C function that follows the
`box_args_t` calling convention. The functions are pure C and
freestanding; they call only the kernel facilities already
established (debug-write through CDC-ACM, panic through the
exception handler, the worker context's rng).

## Suggested implementation steps

1. `debug_write_box()`, `timer_box()`, `panic_box()`,
   `random_byte_box()`.
2. Descriptor entries for each in 208's table.
3. Tiny inline test exercising each through a one-box map.

## Related documents

- `docs/012-soramech-runtime.md`.

## Blocked by

105 (panic stub), 110 (debug write), 202 (worker rng state),
208 (descriptor table).

## Blocks

311 (the demo wires debug-write).
