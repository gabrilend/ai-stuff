# 110o — probes leave hardware as-found, and flag registers off their reset value

Makes the probe battery **conservative**: a probe returns every register it
touched to the value it found there, so the sweep hands each probe — and the
rest of boot — the same hardware state it started from. And it makes the
sweep **observant**: where a probe knows a register's power-on value, it
reads that register at entry and logs loudly if the bootloader or firmware
already moved it. 110i baked the battery in; 110n made the runner callable;
this makes each probe clean up after itself and notice a dirty starting line.

## Current behavior

A probe that ungates a clock or releases a reset leaves it that way. The
clearest case is `display-presence`: it ungates the VOP2 + VO bus clocks
(`CLKGATE_CON20` @ `0xFDD20350`) and releases the VOP2 resets
(`SOFTRST_CON16` @ `0xFDD20440`) so it can read the version register, and
never re-gates them — so every probe after it, and the kernel past the
sweep, inherits a display block that is powered and out of reset even though
nothing asked for it. The hand-written C probes do the same with their own
domains: `otp_probe` ungates the OTP clocks (`CLKGATE_CON26`,
`SOFTRST_CON22`), `rng_probe` and `crypto_probe` ungate the crypto complex
(`CLKGATE_CON8`, `SOFTRST_CON6`), and `i2c0_setup` — shared by five probes —
ungates i2c0's PMU-domain clocks and re-routes two GPIO pads to the i2c0
function, all left in place on exit.

The instinct already exists in two spots: `pmic_write_test` reads the RK817
byte it is about to change and writes the original back; `pmic_ldo_test`
reprograms LDO1 to the voltage it just read. Both restore their *device*
register but neither restores the i2c0 *bus* bring-up underneath them. So the
invariant is believed in, applied by hand, and only partially.

Nothing reads a register's reset value to notice a non-default starting
state. `EXPECT` checks a value the probe *wants after acting*; there is no
"what was here before I touched anything" check.

## Intended behavior

Two properties, kept deliberately separate because they need different
knowledge:

### 1. As-found restore — the probe puts back what it changed

Restore correctness comes from **saving the real entry value and writing it
back**, never from guessing a reset value — so it is right no matter what the
starting state was. Per the 110o design call, the engine gains **no
auto-journal**: each probe (or C routine) restores itself explicitly, because
the author is the one who knows which registers are write-mask registers and
what the correct write-back is. The engine stays dumb; the knowledge lives
where the writes do.

The subtlety this is built around: the CRU/GRF **write-mask** registers carry
a per-bit write-enable in bits 31:16 and the values in bits 15:0. Reading one
returns the live low half with the mask half `0`, so **writing that value
straight back changes nothing** — the restore silently no-ops. The correct
write-back is `0xFFFF0000 | (saved & 0xFFFF)`: enable every bit, write the
saved state. A plain peripheral like `I2C0_CLKDIV` (`0xFDD40004`) sits in the
same address window but is **not** masked — both 16-bit halves are real — so
it must be restored raw. There is no address rule that separates them; the
author picks the right form per register.

- **Script (`W`) probes** snapshot each register they will change with a new
  `SAVE <addr>` at entry and put it back with `RESTORE <addr> [maskbits]` at
  exit — restoring the *actual value found*, not the reset value. This is what
  lets a probe run after another subsystem legitimately turned a block on and
  still leave it on: `SAVE` captures the on-state, the ungate is a no-op,
  `RESTORE` writes the on-state back. `maskbits` names the bits the probe
  touched and selects the write-mask form (`(maskbits<<16) | (saved &
  maskbits)`), mandatory for a CRU/GRF register because a raw write-back of its
  read value no-ops; omitting `maskbits` restores a plain register raw. A small
  per-probe slot table holds the snapshots and is cleared before each probe.
- **C routines** save the full register at entry (before the first write) and
  write it back at teardown via one shared helper, `cru_restore(addr, saved)`,
  which applies the masked formula in a single commented place. The shared
  `i2c0_setup` gets a matching `i2c0_teardown()` that restores the five
  registers it changed (their entry values stashed at setup time); every
  i2c-using probe brackets `i2c0_setup ... i2c0_teardown`. This generalises
  what `pmic_write_test` already does by hand.

### 2. Reset-value check — a new `DEFAULT` command

Only the probe (from the TRM) knows a register's power-on value, so the check
is declarative:

- **`DEFAULT <addr> <value> [mask]`** — read `addr` (32-bit), mask, compare to
  `value & mask`. Log `DEFAULT <addr> at-reset` when equal, or
  `DEFAULT <addr> NON-DEFAULT got=X reset=Y` when not. It changes no state; it
  is pure observation placed at the *top* of a probe, before any write.

The two features are independent by design. Restore correctness does **not**
depend on the register having started at reset — `SAVE`/`RESTORE` capture and
return the real entry value whatever it was, on or off. `DEFAULT` is then
purely diagnostic: a `NON-DEFAULT` log tells you something upstream (the
bootloader, another subsystem) already moved this register, which is worth
knowing on its own, but the restore is correct either way. This matters
because the sweep may run *after* the display (or any block) was legitimately
brought up for other reasons — the probe must hand it back on, not reset it.

Out of scope here (peripheral-register residue that does not persist as a
powered clock domain — e.g. the RNG's `rng_enable` bit) is noted in comments
where left, per the fallback-is-a-warning rule.

## Suggested implementation steps

1. Write this issue (done before any code).
2. `src/019-probe-engine.c`: add the `DEFAULT`, `SAVE`, and `RESTORE` commands
   to `run_line` (DEFAULT reads+compares+logs; SAVE snapshots into a per-probe
   slot table cleared each run; RESTORE writes the snapshot back, raw or in
   write-mask form per an optional maskbits argument); add the
   `cru_restore(addr, saved)` helper the C side shares.
3. Same file, C routines (the "everything now" scope): stash-and-restore the
   CRU state in `otp_probe`/`otp_read_cpuid`, `rng_probe`, `crypto_probe`; add
   `i2c0_teardown()` plus the file-scope saved values in `i2c0_setup`, and
   bracket the five i2c callers (`pmic_dump`, `pmic_write_test`,
   `pmic_ldo_test`, `i2c0_scan`, `audio_codec_recon`).
4. `input/probes/display-presence.probe`: `SAVE` the two CRU registers and
   `DEFAULT`-check them at entry; `RESTORE` them (with touched-bit maskbits)
   after the version read.
5. Build `--debug`; confirm the engine still compiles and the run-list is
   unchanged. Reassemble the bootable SD image.
6. On the next hardware sweep, confirm the log shows the `SAVE` values, the
   `DEFAULT` results, and that the block is left in its entry state — re-gated
   if we found it gated, still on if we found it on (the restore held).

## Related documents and tools

- `src/019-probe-engine.c` — the engine gaining `DEFAULT`, `cru_restore`,
  `i2c0_teardown`, and the C-routine save/restore brackets.
- `input/probes/display-presence.probe` — the first script probe to declare a
  reset value and restore its writes; the worked example for the rest.
- `docs/023-display-controller.md` / `docs/017-clocks-and-timers.md` — the
  VOP2 and CRU register facts the `DEFAULT` values are drawn from.
- `issues/completed/110i-dynamic-hardware-probe.md` — the battery and the
  `R`/`W`/`EXPECT`/... language this extends.
- `issues/110n-callable-run-probes-and-runflags.md` — the callable runner that
  makes "a re-run finds it re-gated" a real test.

## Blocked by

Nothing. 110i and 110n are in place; this is additive — one new read-only
command plus restore writes.

## Deferred / future

Nothing outstanding on the mechanism. The heavier C routines still restore all
sixteen low bits of a shared CRU register (via `cru_restore`) rather than only
the bits they touched, which is safe today because the sweep is single-threaded
with interrupts masked — no other code changes those registers between a
routine's save and restore. If that ever stops holding, give the C side the
same touched-bits-only precision the script `RESTORE <addr> <maskbits>` form
already has.
