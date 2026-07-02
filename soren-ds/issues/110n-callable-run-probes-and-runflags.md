# 110n — a callable run_probes() over a mutable run-flag array

Turns the probe battery from a fixed boot-time sweep into a
runtime-mutable, callable diagnostic engine. 110i baked the probes into
the image; 110k added a per-probe run/skip bit read at build time. This
lifts that bit out of the compiled struct into a **mutable array the
kernel owns at runtime**, wraps the sweep in a **callable `run_probes()`**,
and makes each probe **self-clearing** — so the same machinery fires from
boot bring-up, and later from a button combo or a USB console, not just
once at power-on.

## Current behavior

**Core implemented and build-verified (this refactor).** In place now: the
mutable `probe_runflags[]` array, the callable self-clearing `run_probes()`,
`probe_arm(enum probe_index)`, `probe_seed_defaults()`, the generated
`probe-index.inc` enum, the `#NEEDED`-defaults-to-0 flip, and the
`--debug`-primary / deprecated-`--probes` build flag (`SOREN_PROBES` macro
renamed `SOREN_DEBUG`). `kernel_main` seeds the flags and calls `run_probes()`
at boot. Still pending: converting the diagnostic health checks to probes,
dropping the terminal park so a debug build boots through, a `#CRITICAL`
abort-on-fail marker (needs per-probe pass/fail propagation), and a hardware
smoke-test of the reworked boot path.

### What this replaced

A `--debug` build runs `scripts/embed-probes`, which bakes every `#AUTO`
probe under `input/probes/` into `tmp/build/generated/probe-list.inc` as a
`builtin_probes[]` array in `src/019-probe-engine.c` — each entry
`{ name, writes_enabled, needed, text }`, ordered by `#AUTO` priority.
`probe_engine_run()` walks the array once, runs each entry whose `needed`
field is 1 through the interpreter (`R`/`W`/`DUMP`/`DELAY`/`EXPECT`/`POLL`/
`CALL`/`LOG`), brackets each with `===== PROBE name =====` banners, flushes
the SD-backed debug log after each, and logs a `DE-SELECTED` banner where
`needed` is 0. The amber LED advances as a progress bar over every index.

Three properties make it inflexible:

- **The run/skip bit is compiled in, not mutable.** `needed` is a fixed
  field in the baked struct. Changing what runs is a rebuild.
- **The runner is not callable.** `probe_engine_run()` is invoked once from
  `kernel_main` under `#ifdef SOREN_PROBES`, and the sweep is *terminal* —
  when it finishes the kernel parks. Nothing else can fire a probe, and a
  probe can't be re-run without a reboot.
- **`#NEEDED` defaults to run** (110k: no marker = needed), so the battery
  is opt-out.

## Intended behavior

A mutable run-flag array plus a callable, self-clearing runner:

- **`probe_runflags[]`** — one mutable slot per baked probe, in sweep
  (priority) order; 1 = armed, 0 = idle. A plain byte-per-probe array
  (legible and directly indexable) rather than a packed bitword. This is
  the *runtime* run-list, distinct from each probe's compiled-in default.
- **`run_probes()`** — callable from anywhere. Walks `probe_runflags[]` in
  priority order; for each armed slot, runs that probe through the existing
  interpreter, commits its output (the SD-backed log always; screen / audio
  / other sinks as those come up), then **clears that slot to 0**. A slot
  reading 0 means "not armed, or already ran and its results are safely
  written." Re-arm to re-run.
- **Debug-gated seeding.** `#NEEDED` flips to default **0** (opt-in). At
  bring-up, in a debug build only, the flags are seeded to 1 for the
  `#NEEDED 1` probes; a production build seeds nothing and the engine
  compiles out, so a production image runs no probes. Opt-in (not 110k's
  opt-out) so a newly-added or experimental probe never auto-runs on a
  debug boot until it is explicitly armed.
- **Armable by any code.** A function arms a probe by setting its slot
  (`probe_runflags[PROBE_x] = 1`) and calling `run_probes()`. This is the
  runtime-trigger seam sketched earlier (the boot-button reader / the USB
  console): set a flag, fire the runner, no rebuild. Probes get stable
  indices via a generated `enum probe_index` so callers can name them.
- **Woven into bring-up, not terminal.** `kernel_main` calls `run_probes()`
  inline at the point where the log surface is up, instead of the terminal
  park-and-sweep. In a debug build the armed verification probes run in
  dependency order during bring-up; in production `run_probes()` is a
  no-op. The heavy/deliberate probes (full dump, bootloader backup, RAM
  march) stay **unarmed by default even in a debug build** — armed on
  demand.

### The line between bring-up and probes

Bring-up and verification are kept separate, so a debug-only run-flag can
never silently disable a production safety check:

- **Driver init and its fail-loud gate stay always-on C, in every build.**
  `allocator_init`, `sd_init`, `emmc_init`, `usb_init` and their
  panic-on-failure branches are bring-up-with-error-handling, not
  diagnostics — if the SD card does not come up there is no log surface; if
  the allocator is broken nothing works. Per the project's fail-loud
  principle these never become a debug-gated probe.
- **Probes are the verification/diagnostic layer on top.** The "health
  checks" that convert to probes are the *self-tests and read-backs* — the
  allocator bitmap self-test, the controller register-signature checks, the
  data fingerprints — not the init-or-panic gates. A probe's job is to
  *confirm and report*; a gate's job is to *stop the boot*.

### Criticality and ordering

Probes run in priority order, most-foundational first — the order in which
each unblocks the next:

1. the SD-log surface itself (everything downstream writes there),
2. DRAM soundness,
3. the generic timer (so later probes can measure real elapsed time, not
   nop counts),
4. the storage / power / peripheral checks that depend on the above.

A probe may be marked **critical** — its failure aborts the remaining
sweep (there is no point fingerprinting an eMMC read if the log it writes
to is dead) — versus **diagnostic**, whose failure is logged and the sweep
continues. This is a per-probe marker alongside `#AUTO` / `#WRITES` /
`#NEEDED`.

## Suggested implementation steps

1. Write this issue (done before any code).
2. `scripts/embed-probes`: emit an `enum probe_index` (one name per probe,
   sweep order) and a `probe_defaults[]` seed row from the `#NEEDED` bits;
   flip `probe_needed`'s default from true to false; add a `#CRITICAL`
   reader alongside the existing marker readers.
3. `src/019-probe-engine.c`: add the mutable `probe_runflags[]`; add
   `run_probes()` (walk armed slots in order, run, commit output,
   self-clear, honour critical-abort); add a `probe_arm(enum probe_index)`
   helper for other callers. Keep `probe_engine_run` as a thin "seed
   defaults + run_probes()" boot entry, or fold it in.
4. Build flag: rename `--probes` → `--debug` in `scripts/build` (or keep —
   see the naming call), keep `-DSOREN_PROBES` as the compile guard so a
   production build still emits an empty engine object.
5. `src/002-main.c`: leave the always-on init + panic gates in place; call
   `run_probes()` inline once the SD log is up; drop the terminal
   park-after-sweep so a debug build boots like production with probes woven
   in.
6. Convert the diagnostic health checks (the allocator self-test; the
   inline SD/eMMC "checkpoint" read-backs) into probes with priorities that
   put the unblockers first; keep their fail-loud gates as C.
7. Build both variants; confirm production has an empty engine object and
   runs nothing, and the debug build seeds + runs the armed set in order and
   self-clears.

## Related documents and tools

- `src/019-probe-engine.c` — the engine gaining the array + callable runner.
- `scripts/embed-probes` — the generator gaining the index enum, the seed
  row, and the `#CRITICAL` marker.
- `src/002-main.c` — the boot path the runner is woven into.
- `issues/completed/110i-dynamic-hardware-probe.md` — the compiled-in
  battery this builds on; its "future USB console" note is the seam this
  opens.
- `issues/completed/110k-probe-run-list-selection.md` — the static run-list
  this makes mutable.
- `src/018-bringup-test-suite.c` — an early always-on check-runner this
  generalises; a candidate to fold into the probe set.
- `docs/015-led-diagnostic-codes.md` — the LED progress bar the runner
  drives.

## Blocked by

Nothing hard — 110i (battery) and 110k (run-list) are complete and verified
on hardware; this is a refactor on top of them.
