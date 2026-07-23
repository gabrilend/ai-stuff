# 110q — one-shot eMMC wipe (temporary, delete after use)

A deliberate, destructive, **one-shot** tool that erases the entire eMMC, so the
device boots only from SD and the stock Rockchip boot chain stops claiming the
USB OTG port when a host is connected. This unblocks the USB device-mode test
(milestone (b) of 109b): with the eMMC blank, plugging the OTG port into a PC
lets our SD-booted kernel's gadget present itself instead of the eMMC's boot/
loader grabbing the port.

**This issue is deliberately temporary.** After the wipe has run once and been
confirmed, the probe and its CALL target are to be REMOVED (see "Teardown").

## Current behavior

`emmc_erase_all()` in `src/012-emmc.c` blanks the whole card via the card's own
ERASE command — `CMD35` (erase-group start = 0), `CMD36` (erase-group end =
`SEC_COUNT-1`), `CMD38` (erase) — then waits out the DAT0 busy and reads back the
boot-critical blocks (LBA 0 / 64 / 16384) to confirm they are blank. It is
reached by the `emmc_wipe` CALL target in `src/019-probe-engine.c`, armed by the
`emmc-wipe.probe` at priority 200 (runs last, after all recon).

Why ERASE and not zero-writing: our only eMMC write path is single-block PIO
(`emmc_write_block`); zeroing all ~29 GB that way would take hours and program
every cell. The card's ERASE blanks whole erase-groups internally — far faster
and gentler on the flash. Erased content reads back as the card's factory value
(0x00 on most eMMC, 0xFF on some); either way the boot chain is gone.

It fails SAFE: a rejected `CMD35/36/38` leaves the card untouched and logs which
command was refused.

## Recovery (must be in hand before running)

- `archives/golden-sd-*.img.gz` — a known-good SD image that boots our kernel
  regardless of eMMC state.
- `archives/bootchain-*.bin.gz` — the stock Rockchip boot chain (LBA 0..32767),
  checksum-verified, writable back to the eMMC via `emmc_write_block` if we ever
  want the factory bootloader again.

Since the device boots from SD independently of the eMMC (proven by every sweep),
a blank eMMC does not stop SD boot. The wipe is therefore recoverable through the
SD path without needing Maskrom.

## Teardown (do not forget)

Once the wipe has run and the USB test has moved forward:

1. Delete `input/probes/emmc-wipe.probe`.
2. Delete the `emmc_wipe` branch in `src/019-probe-engine.c`'s `call_target`.
3. Keep `emmc_erase_all()` in `012-emmc.c` (a legitimate storage primitive) OR
   remove it too if nothing else uses it — decide at teardown.
4. Rebuild and confirm the wipe probe is gone from the roster.

## Related

- `notes/safety/000-bricking-and-recovery.md` — the recovery-net rules this
  leans on.
- `issues/completed/110b-bootable-emmc-overwrite.md` — the eMMC write path and
  the "SD is the rollback" model.
- `archives/README.md` — the golden SD + boot-chain archive.
