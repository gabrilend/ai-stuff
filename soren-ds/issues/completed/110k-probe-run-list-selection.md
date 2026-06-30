# 110k — per-probe run-list (select which compiled-in probes run)

Builds directly on 110i (the compiled-in probe battery). 110i removed
the lab-side *selection* of probes; this adds selection back one layer
up, at build time, where a build flag already means a rebuild.

## Current behavior

A `--probes` build (110i) embeds every `#AUTO`-marked probe under
`input/probes/` and runs **all** of them, in priority order, on every
boot. A probe carries two header directives today, both read at build
time by `scripts/embed-probes`:

- `#AUTO [N]` — join the battery, and run at priority `N` (lower goes
  first). No `#AUTO` line at all = manual-only, excluded from the
  compiled-in battery entirely.
- `#WRITES` — set the writes-enabled bit so the engine honours this
  probe's `W`/`WH`/`WB` register pokes.

The generator emits one `builtin_probes[]` initializer per kept probe
(`{ name, writes_enabled, text }`) into `tmp/build/generated/
probe-list.inc`; `src/019-probe-engine.c` `#include`s it and the sweep
loop in `probe_engine_run` walks every entry.

The gap: there is no way to keep a probe in the battery but skip it for
one build. The only on/off knob is `#AUTO` itself, and removing it
drops the probe from the image entirely — its name, its text, its place
in the ordering all vanish. "Stop running the PWM bring-up probe for
now, but keep it around" has no expression short of deleting or
commenting out its `#AUTO` line and later restoring it.

## Intended behavior

A third per-probe directive, `#NEEDED`, decides whether a compiled-in
probe actually *runs* this build — independently of whether it is
compiled in (`#AUTO`) and whether it may write (`#WRITES`):

- `#NEEDED 1`, or a bare `#NEEDED` — run this build.
- `#NEEDED 0` — compiled in (present in the image and in the boot
  log's roster) but **de-selected**: the engine skips its body and logs
  a one-line `DE-SELECTED` banner where the probe would have run.
- no `#NEEDED` line — defaults to needed (1), preserving 110i's
  run-them-all behaviour for any probe that predates or omits the flag.

The generator collects these into the built image as **a row of 0/1
bits, one per probe in sweep order** — the literal "list that says what
runs this time." It lands two ways:

- as a `needed` field on each `builtin_probes[]` entry (the column the
  engine reads), and
- as a human-readable `run-list: 1 1 1 0 …` line in the generated
  file's header comment, so the whole selection is visible at a glance
  in one place rather than scattered across a dozen probe files.

All of this is inside `--probes` (`#ifdef SOREN_PROBES`); a lean
production build has no probe engine, so no run-list.

### Why a separate flag instead of just removing `#AUTO`

Two reasons to keep a de-selected probe in the image rather than drop
it:

- **The log stays honest.** A de-selected probe's name still appears in
  the boot roster with a `DE-SELECTED` banner, so the log shows it was
  *deliberately* skipped — not silently missing. ("De-selected" is more
  informative than "not selected.")
- **The edit is small and obviously reversible.** Flipping one bit from
  1 to 0 and back is a smaller, safer change than surgically removing an
  `#AUTO` marker (and its priority number, and remembering to restore
  it).

### Why this belongs at build time (and why 110i removed it)

110i retired the SD-card catalog that let a lab tech pick probes,
because the only thing that justified it — choosing probes *without a
rebuild* — became moot the moment delivery was a build flag (a flag is
a rebuild). That argument kills *flash-time* selection. It does **not**
kill *build-time* selection: editing a `#NEEDED` bit and rebuilding sits
in the exact same edit-and-rebuild loop as editing the probe's `R`/`W`
text, which 110i kept precisely because it is cheaper than editing C.
So selection returns at the layer where it costs nothing extra.

### First use

The PWM bring-up probe is now redundant: the LED layer (`003-pwm.c`'s
`led_pwm_init`/`led_top`/`led_bottom`) drives the PWM channels directly,
so the bring-up probe only adds a brief red flicker mid-sweep. It is the
natural first `#NEEDED 0` — quieted without being thrown away — and
de-selecting it doubles as the hardware test of the gate (its
`DE-SELECTED` banner should appear in the log in place of its body).
This is left for an explicit go-ahead, not done as part of wiring the
mechanism.

### Where each piece lives

- `scripts/embed-probes` — a `probe_needed(lines)` reader (mirrors
  `probe_writes`, but defaults *true*); a `needed` field threaded
  through `build_entries`; `emit` writes it as the struct's third field
  and as the header run-list row; the stderr build summary marks the
  de-selected ones.
- `src/019-probe-engine.c` — `struct builtin_probe` gains a `needed`
  field (between `writes_enabled` and `text`); `probe_engine_run` gates
  each probe on it and emits the `DE-SELECTED` banner for the skipped
  ones. The LED loading bar still advances over every index (position in
  the battery), so a de-selected probe ticks past without stalling it.
- `input/probes/*.probe` — each `#AUTO` probe gets an explicit
  `#NEEDED 1` line by its header, so the knob is present and
  discoverable on every probe (not just implied by the default).

`#NEEDED` has meaning only for `#AUTO` probes — the gate lives *within*
the battery. A manual-only probe (no `#AUTO`, e.g.
`example-emmc-registers`) is already excluded and takes no `#NEEDED`.

## Suggested implementation steps

1. Write this issue (done before any code).
2. `embed-probes`: add `probe_needed`, defaulting true when the marker
   is absent; record `needed` on each entry in `build_entries`.
3. `embed-probes`: emit the `needed` bit as the third struct field;
   write a `run-list: …` row into the generated header comment; add the
   de-selected state to the per-probe stderr summary; update the
   file-top description.
4. `019-probe-engine.c`: add `int needed;` to `struct builtin_probe`
   and update the struct's doc comment and the file-top History note.
5. `019-probe-engine.c`: gate the sweep loop on
   `builtin_probes[i].needed`; emit `===== PROBE name DE-SELECTED (not
   needed this build) =====` and `continue` when zero; keep
   `led_bottom(i, count-1)` before the gate so the bar stays uniform.
6. Add `#NEEDED 1` to each `#AUTO` probe under `input/probes/`.
7. Build both variants: lean still an empty `019` object; `--probes`
   regenerates `probe-list.inc` with the four-field initializer and the
   run-list row. Inspect the row.
8. (On explicit request) de-select the PWM bring-up probe (`#NEEDED 0`)
   as the first live use, and flash to confirm its `DE-SELECTED` banner
   appears in the log in place of its body.

## Related documents

- `issues/completed/110i-dynamic-hardware-probe.md` — the compiled-in
  battery this extends; its "Intended behavior" argues selection away at
  the lab-side layer, which this re-introduces at the build layer.
- `issues/110j-fast-emmc-hs200.md` — the fast-storage path; its EXT_CSD
  probe rides this same battery and is a candidate for de-selection once
  HS200 is settled.
- `issues/106c-pwm-controller-bring-up.md` — the PWM/LED layer that made
  the PWM bring-up probe redundant (the first de-selection candidate).

## Blocked by

Nothing. 110i (the compiled-in battery) is complete and verified on
hardware; this is purely additive on top of it.
