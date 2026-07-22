# 000-cassette-encoding-descriptor — info

> Black-box summary of the cassette **encoding scheme** (data at rest). Read this
> instead of the source unless you are changing the format itself. Part of the
> experimental cassette branch (issue 905, Phase 9) — this branch gates nothing.

## What this module is

The single definition of *how bytes become audio tones* on a software-modelled
cassette: a Kansas-City-Standard-flavoured FSK scheme (mark/space tone per bit,
UART-style byte framing, a mark leader). It holds the numbers and the rules; it
does not encode, decode, or view anything — those are 001 / 002 / 003.

## Constants (the symbol vocabulary)

- `M.SPACE = 0`, `M.MARK = 1` — the two bit symbols (the two FSK tones).
- `M.START = 0`, `M.STOP = 1` — the framing bits around each byte.

## External functions

- `M.default_descriptor() -> desc`
  Returns the shipped scheme as a plain table: `sample_rate`, `baud`, `mark_freq`,
  `space_freq`, `amplitude`, `leader_bits`, `symbol_freq` (a `{[0]=space,[1]=mark}`
  dispatch table), and `slice_budget_bytes` (the honest pico-8-sized payload
  ceiling). No side effects.

- `M.validate(desc) -> desc`
  Proves a descriptor well-formed and errors LOUDLY on the first violation. Also
  enforces the exact-decoding invariant: `sample_rate % baud == 0` and each
  frequency an integer multiple of `baud`, so every bit-window is a whole number
  of tone cycles. Returns the same `desc` for convenient chaining.

- `M.samples_per_bit(desc) -> integer`
  The bit-window width in samples (`sample_rate / baud`). Integer by the invariant.

- `M.expected_crossings(desc, symbol) -> number`
  How many zero-crossings one bit-window of that symbol should hold
  (`2 * freq / baud`). The decoder classifies a window by nearest expected count.
  Errors on a symbol outside `{SPACE, MARK}`.

## Notes for a future reader

- The "divides evenly" checks in `validate` are load-bearing: relax them and the
  decoder's clean zero-crossing counts drift, and tapes stop reading. Comment on
  the default numbers explains why 44100 / 300 / 2400 / 1200 were chosen.
- No fallbacks: a malformed scheme is an error, not a silently-patched default.
