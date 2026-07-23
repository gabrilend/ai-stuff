# 110p — an RNG entropy-quality sweep: turn the sample-rate knob, watch it whiten

Turns the single-shot RNG probe into a **quality instrument**. Instead of one
256-bit draw at the fastest sample rate, it draws a full block at each of
several `RNG_SAMPLE_CNT` values and reports a nibble histogram per rate — so a
reader can SEE which sample rate produces well-mixed bits and which produces
the correlated, near-alternating output the fastest rate gives. The point is
to learn the knob: how the oscillator-ring sample spacing trades output rate
for entropy quality.

## Current behavior

The RNG probe (`rng_probe` in `src/019-probe-engine.c`, run by the `CALL
rng_probe` in `input/probes/rng.probe`) does one 256-bit draw at
`RNG_SAMPLE_CNT = 0` — the fastest rate — and logs the eight `DOUT` words with
a crude "all-equal/zero = stuck" note. The first full 256-bit sweep
(2026-07-02) showed the words are *not* stuck but ARE badly biased: nearly
every nibble is `0x5` (0101), `0xA` (1010), or a neighbour, and two of the
eight words came back byte-for-byte identical (`0x6AAA9555`). That is the
signature of sampling the oscillator ring faster than it accumulates
independent jitter — adjacent captured bits are correlated. The crude
"differs = healthy" check passes it anyway, so the probe cannot presently tell
good entropy from bad.

## Intended behavior

Keep generation and viewing separate (project rule), and sweep the knob:

- **Generator** — one routine draws a full 256-bit block at a caller-supplied
  `RNG_SAMPLE_CNT`, waits (bounded) for `rng_start` to self-clear, and returns
  the eight words. It interprets nothing.
- **Viewer** — a second routine takes eight words and prints a 16-bucket
  nibble histogram (of the 64 nibbles) plus the count of 1-bits out of 256.
  Uniform-ish (~4 per nibble, ~128 ones) reads as well-whitened; spikes at
  `0x5`/`0xA` and a skewed bit count read as the correlated-sample bias.
- **Sweep** — the probe ungates the crypto clock domain once, runs the
  generator+viewer for a geometric spread of sample counts (0, 16, 64, 256,
  1024), and restores the clock domain as-found (issue 110o). Each rate's
  histogram sits under its `sample_cnt=` header so the trend is visible at a
  glance.

`RNG_SAMPLE_CNT` is the knob: larger values space the bit captures farther
apart, slowing the output but (the hypothesis) whitening it. The sweep is how
we confirm that and pick a working value, rather than guessing one. A rate
that never completes within the bounded poll logs `TIMEOUT` for that row and
the sweep moves on — never a hang.

## Suggested implementation steps

1. Write this issue (done before any code).
2. `src/019-probe-engine.c`: add the generator (`rng_draw_256`) and viewer
   (`rng_report_quality`); rewrite `rng_probe` to sweep the sample-count array,
   pairing one generator call with one viewer call per rate, inside the
   existing 110o save/restore bracket.
3. Build `--debug`, reassemble the image, flash, sweep. Read the histograms:
   confirm the fastest rate is biased and find the rate at which the nibble
   spread flattens toward uniform.
4. Record the finding — which rate whitens — in this issue's current-behavior
   section (and, if it becomes load-bearing for a real consumer, promote the
   chosen `RNG_SAMPLE_CNT` into a named constant with the measurement behind
   it).

## Related documents and tools

- `src/019-probe-engine.c` — `rng_probe` and the new generator/viewer helpers.
- `input/probes/rng.probe` — the `#AUTO` probe that fires the sweep; unchanged
  (it just `CALL rng_probe`s).
- `docs/datasheets/rk3568-trm-part2.pdf` — TRNG chapter: `RNG_CTL` field map
  (write-enable mask bits 21:16, `rng_len` bits 5:4), `RNG_SAMPLE_CNT`, `DOUT`.
- `issues/110o-probes-leave-hardware-as-found.md` — the save/restore bracket
  the sweep runs inside.

## Blocked by

Nothing. The 256-bit draw and the clock save/restore are already in place;
this restructures the draw into a generator/viewer pair and loops it.
