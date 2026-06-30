# 110i — dynamic hardware probe (compiled in under `--probes`)

> Delivery note: this probe battery began life as an SD-card-driven
> interpreter that a lab tech wrote scripts onto and the kernel read
> back at boot (preserved at the bottom under "Superseded design").
> It is being rebuilt to compile the probes straight into the kernel
> under a build flag. The interpreter and the probe-script language
> survive unchanged; only *how the probes reach the kernel* changed —
> from data living on the card to a blob baked into the image.

## Current behavior

The built-in design below is implemented and both build variants are
green. `scripts/build` produces a lean kernel whose
`019-probe-engine.o` is an empty object — no probe code in the image.
`scripts/build --probes` runs the generator (`scripts/embed-probes`),
which embeds the seven `#AUTO`-marked probes from `input/probes/` into
the kernel in priority order, and the engine walks them on boot. This
is verified at build time: the probe symbols and the embedded probe
text are present in the `--probes` ELF and absent from the lean ELF.
The interpreter (`R`/`W`/`DUMP`/`DELAY`/`EXPECT`/`POLL`/`CALL`/`LOG`)
and its `CALL` targets (`sd_init`, `emmc_init`, `emmc_read0`,
`backup200`, `memtest`, `pmic_dump`) are unchanged from the version
already exercised; only the front end that fetches probes changed.

The old SD-card delivery is retired. `load_probe_catalog` is gone from
`flash-sd` (back to unmount → one `dd` → eject); `select-probe`,
`write-probe`, and `probe-common.sh` are archived under
`scripts/lab-side/retired/`; `push-to-usb` no longer syncs
`input/probes/` to the drive; and the SD probe-region notes are out of
`docs/016-physical-memory-map.md`.

Verified on real hardware (2026-06-29). A `--probes` image flashed and
booted ran all seven probes start to finish — each bracketed by its
START/END banner, none hung — and parked at the done LED (top red +
bottom amber, *not* the long backup grind), confirming the boot-time
hand-off (kernel_main → embedded sweep → park) works. `dump-from-sd`
split the swept log into seven per-probe files.

The sweep doubled as a phase-1 health report: DRAM memtest PASS; eMMC
alive (CID 0x00010AA9, caps 0x226DC881, block 0 reads real data); the
**eMMC DLL locks at 200 MHz** (DLL_STATUS0 = 0x13B, lock value 0x3B —
this greenlights the HS200 fast path, filed as 110j); USB2 PHY in
OTG-normal state (0x0C52); DWC3 core readable (GSNPSID 0x5533300A). It
also surfaced three leads for other issues: the VOP2 display reads
version 0x40158023 (alive — the probe's expected value was corrected
from a TRM guess), the SARADC converts channel 0 but times out on 1–5,
and the RK817 PMIC does not answer over i2c0. The probe engine itself
is done; those three are inputs to their own subsystem work, not to
this issue.

One bug surfaced and was fixed in the read-back tooling, not the
engine: `dump-from-sd`'s log-splitter ran its file-writing `awk`
without `sudo`, so it could not create the per-probe files in the
root-owned `lab-output/` on the drive ("cannot redirect … Permission
denied"). The `awk` now runs under `sudo`, matching the `dd` dumps
beside it.

## Intended behavior

Probes are compiled into the kernel as part of the build. A normal
`scripts/build` produces a lean, probe-free kernel. A
`scripts/build --probes` build embeds every probe in `input/probes/`
and, on boot, runs them all — the whole battery, in priority order —
then parks with the log preserved. No card writes, no lab-side
selection, no SD probe regions. The diagnostic kernel is a *build
variant*, not a data payload carried on the card.

This is the right shape because the two ideas that justified the
SD-card design are both gone:

- The interpreter existed so a probe could change *without a kernel
  rebuild*. A build flag **is** a rebuild, so that benefit no longer
  applies — we rebuild either way.
- The catalog existed so a lab tech could *select* which probes to
  ship. We decided to run them all every time (they are quick), so
  there is nothing left to select.

What stays worth keeping is the interpreter itself and the
probe-script text format: writing a probe as a few `R`/`W`/`EXPECT`
lines is more pleasant than hand-writing MMIO accessors in C, and the
eight existing probes are already in that form. So the language
stays; only the transport changes.

### The probe script language (unchanged)

A tiny line-oriented interpreter. One command per line; `#` begins a
comment; blank lines ignored. The minimum useful set:

- `R <addr>` — read a 32-bit word at `addr`, log `addr = value`.
- `RH <addr>` / `RB <addr>` — 16-bit / 8-bit read.
- `W <addr> <val>` — write a 32-bit word.
- `WH` / `WB` — 16-bit / 8-bit write.
- `DUMP <addr> <count>` — log `count` consecutive 32-bit words.
- `DELAY <n>` — busy-delay roughly `n` loop units.
- `EXPECT <addr> <val> <mask>` — read, AND with mask, compare to
  val, log `PASS`/`FAIL`. Lets a script be a self-checking test.
- `CALL <name>` — invoke a named built-in routine from a small
  dispatch table (`sd_init`, `emmc_init`, `emmc_read0`, etc.) so
  scripts can exercise whole driver entry points, not just raw
  registers.
- `LABEL` / `LOG <text>` — emit a literal marker into the log so
  the output is readable.

The address and value tokens are hex. The interpreter is
deliberately dumb — no arithmetic, no variables, no control flow
beyond top-to-bottom. Anything more complex belongs in C.

### How the probes are embedded

At `--probes` build time a small generator (Lua, LuaJIT-compatible
per project convention) reads every `input/probes/*.probe`, orders
them by their `#AUTO` priority (lower runs first), and bakes each one
— name, writes-enabled flag, and the raw script text as a byte array
— into a generated C source file. That file declares a
`builtin_probes[]` array and a count the engine walks.

The generator writes its output into the RAM-backed build directory
(`tmp/build/`), **outside** `src/`, for two reasons: the Makefile's
`find $(SRC_DIR) -name '*.c'` glob never picks it up in a normal
build (so no stale blob from a previous `--probes` run can leak into
a production image), and the RAM directory keeps the derived artifact
off the SSD. The build is told to compile the probe engine and the
generated blob, and to define `-DSOREN_PROBES`, only when the flag is
present.

A probe still joins the battery — and gets its run order — through an
`#AUTO [N]` marker line; its writes-enabled bit still comes from a
`#WRITES` marker. The difference is *when* those markers are read:
the generator reads them at build time, where the lab tooling used to
read them at flash time. (The marker-parsing logic that lived in
`probe-common.sh` moves into the generator.)

### Running the battery

On a `--probes` boot, after the SD block driver and the debug log are
up, the kernel walks the embedded array in order, runs each probe
through the interpreter bracketed by `===== PROBE name =====`
banners, and flushes the log after each one. Because the engine is
single-threaded and cannot preempt, a probe that hangs leaves
everything before it already safe on the card — the stuck probe is
the last START banner with no matching END. When the battery
finishes, the core parks; the developer pulls the card and reads the
log with `dump-from-sd`, which still splits the swept log into one
file per probe.

### The safety boundary (unchanged)

The probe interpreter can read and write arbitrary MMIO, which is
powerful and dangerous. Guard rails:

- An allowlist of address ranges the interpreter will touch (the
  peripheral register windows from `docs/016-physical-memory-map.md`);
  a `W` outside the allowlist is logged and skipped, not executed.
- Write commands are only honoured if the probe carries an explicit
  "writes enabled" flag (the `#WRITES` marker), so a read-only probe
  cannot accidentally poke a register.
- The interpreter never touches the eMMC or SD storage regions by raw
  `W` — those go through the block drivers' own calls via `CALL`,
  which carry their own bounds checks.

## Why a build flag and not the card

The eMMC bring-up was the original argument for SD delivery: a
one-line clock-source fix took a dozen reflash cycles to find because
each hypothesis needed a recompile. But the cure we built — writing
probe data onto the card after the flash — turned out to have its own
fragile, *invisible* step: the post-flash whole-disk write that the
laptop's automounter keeps breaking, failing silently. Several flash
cycles were then burned not on hypotheses but on the delivery
mechanism itself.

Compiling the probes in trades the SD write (which we cannot see or
test on the air-gapped laptop) for an extra build flag (which we run
and verify on the main machine, where the bytes are inspectable
before they ship). The image is written by one large `dd` that
already works on every boot — it is what puts the kernel on the card
— so the probe blob rides in on the transport we trust. The slow
edit-rebuild loop the interpreter was meant to avoid is still avoided
*for register tweaks*: editing a `.probe` text file and rebuilding is
far cheaper than editing and rebuilding C, even though both are
rebuilds.

## Relationship to the live USB console (future)

The richer form — a genuinely interactive console where the developer
types probe commands over USB CDC-ACM and sees results live while the
kernel runs — depends on the USB device stack (109a/109b) coming up.
When it does, the same interpreter core can be fed from the USB
channel instead of (or in addition to) the embedded array. The
language and the dispatch table are shared; only the input source
differs. This is the same separation the SD design relied on; moving
the default source from "card region" to "embedded blob" does not
disturb it.

## Suggested implementation steps

1. Rewrite this issue to the built-in design (this document) before
   touching code.
2. Add a `--probes` flag to `scripts/build` (treated as a flag, not a
   make target) that runs the generator and passes `-DSOREN_PROBES`
   plus the generated object through the Makefile.
3. Write the generator: read `input/probes/*.probe`, sort by `#AUTO`,
   emit `builtin_probes[]` (name, writes flag, byte array) into
   `tmp/build/`.
4. Wrap `src/019-probe-engine.c`'s body in `#ifdef SOREN_PROBES` so a
   normal build compiles it to an empty object — no probe code in a
   production image.
5. Replace the engine's SD-card front end (`probe_engine_run` /
   the catalog-manifest reader) with one that walks `builtin_probes[]`
   in order; keep the interpreter and every `CALL` target as-is.
6. Guard the `kernel_main` probe call with `#ifdef SOREN_PROBES`: run
   the battery and park on a `--probes` build; go straight to the
   normal flow otherwise.
7. Retire the SD-driven machinery: `load_probe_catalog` (flash-sd
   returns to unmount → one `dd` → eject), `select-probe`,
   `write-probe`, `probe-common.sh`, and the SD probe-region notes in
   `docs/016-physical-memory-map.md`. Archive, don't silently delete;
   grep for stragglers.

## Superseded design: SD-card delivery

Kept as the story of how this came to be, and because the safety
model and the script language carried straight over.

The kernel read its one active probe from a reserved microSD region
(LBA `0x100000`), with a magic header selecting the mode: `SPRB` =
one embedded script follows, `SPRA` = run the whole catalog. The
**catalog** at LBA `0x180000` held every probe in numbered 32-block
slots, slot 0 a plain-text manifest (`name slot writes auto`) led by
an `SPCT` sentinel. `flash-sd` wrote the entire catalog on every
flash and armed an `SPRA` run-all sweep by default; `select-probe`
narrowed to one probe or re-armed the sweep; `write-probe` pushed a
single ad-hoc script. The LBA constants lived once in
`scripts/lab-side/probe-common.sh`, matched to the kernel and to
`docs/016-physical-memory-map.md`.

It died on the post-flash write race described under "Current
behavior": modern kernels refuse whole-disk writes while a partition
is mounted, and the laptop's automounter kept re-mounting the card
between the tool's `dd`s. A held-open-fd workaround was attempted
(hold one writer open across the whole catalog write, which both
blocks the automounter and suppresses the per-close partition rescan)
and its byte layout was verified off-device, but by then the simpler
truth was clear: with run-all as the only mode and a rebuild required
regardless, the card never needed to carry the probes at all.

## Related documents

- `docs/016-physical-memory-map.md` — the MMIO allowlist ranges the
  interpreter enforces. (Its SD probe-region layout notes are removed
  as part of step 7.)
- `issues/110h-phase-1-bringup-test-suite.md` — the static test
  runner this generalizes; the suite is one built-in `CALL` target.
- `issues/110g-sd-card-debug-log.md` — the output channel the probe
  results still flow through.

## Blocked by

110g (SD-card debug log) — the probe results are written there; it is
working. The probe engine no longer needs SD *reads* now that probes
are compiled in, so the old dependency on 110f's read path is gone
(the log still uses 110f's write path).
