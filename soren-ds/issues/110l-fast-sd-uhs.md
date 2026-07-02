# 110l — fast SD path (4-bit, High-Speed, and UHS-I where the board allows)

The write side of a fast eMMC→SD backup. The eMMC read path is fast now
(110j: HS200 working, HS400 transitioning), but the copy is bottlenecked
by the SD *write*, which still runs at the slowest setting. This brings
the microSD controller up the speed ladder the same staged way the eMMC
went — but on a different controller, with a different ladder, and gated
on a board-voltage question.

## Current behavior

`src/015-sdmmc.c` brings the microSD up on the RK3568's SDMMC0 — a
Synopsys DW MSHC (DesignWare Mobile Storage Host Controller), a wholly
different IP from the eMMC's SDHCI/dwcmshc (different registers, command
model, FIFO). It runs the card at its most conservative setting: a 1-bit
data bus and a 25 MHz card clock (`CLKDIV` divisor 1 on a 50 MHz source),
polled single-block PIO. Reads and writes work and are verified.

New this round, the **dynamic capability probe** (`sd_probe_capabilities`,
the `sd-capabilities` probe): over that slow path it reads the card's SCR
(spec version, bus widths), SD_STATUS (write speed class + UHS grade), and
the SWITCH_FUNC query (which access modes the card offers). This is the
"ask the card what it can do" step — the SD analogue of reading the eMMC
EXT_CSD before HS200 — and it is read-only.

## Intended behavior

Take the lowest of three ceilings, and run the card there:

1. **Host/board ceiling** — what the DW MSHC *and the board's SD-slot
   signalling* can reach. SDR50/SDR104 (UHS-I) require switching the
   card's I/O rail (VCCQ) to 1.8 V; if the slot's signalling is fixed at
   3.3 V (no software-switchable rail), the ceiling is High-Speed
   (50 MHz, 3.3 V). This is the same question the eMMC's VCCQ posed — it
   must be answered from the board (a `vqmmc-supply` on the SDMMC0
   device-tree node) before UHS is attempted.
2. **Card mode ceiling** — the fastest access mode the card advertises
   (from the SWITCH_FUNC query: SDR12 / HS-SDR25 / SDR50 / SDR104 /
   DDR50).
3. **Card sustained-write ceiling** — the card's guaranteed write rate
   from its Speed Class / UHS grade (SD_STATUS). A U1 card sustains
   ~10 MB/s writes, U3/V30 ~30 MB/s, regardless of how fast the *bus*
   runs. This doesn't change the bus mode picked, but it sets the
   realistic throughput and tells us when UHS isn't worth the risk.

The bus mode used = min(ceiling 1, ceiling 2); the throughput expectation
= ceiling 3. The capability probe + the board-voltage check feed the
choice; nothing is hard-coded.

### When the card is probed — at runtime, never baked in

The ceilings are read from the card *every time*, not compiled in — even
though development reuses one card. A card's capabilities and its write
class are properties of *the card in the slot right now*, and the slot's
contents change. So the capability read (ceilings 2 and 3) must run:

- **Every transfer**, at minimum — cheap insurance that we never drive a
  just-swapped card at a mode it cannot do.
- **Ideally, on card insertion** — the DW MSHC exposes a card-detect line
  (its `CDETECT` register, offset 0x50); an insertion event re-runs init +
  the capability probe and caches the result, so the cost is paid once per
  card, not once per copy.
- **And at bring-up**, because the card may already be seated when the
  device powers on (inserted while off) — there is no insertion event to
  catch then, so a boot-time probe covers it.

The last two are deferred: there is no "card inserted" interrupt handler
and no dedicated bring-up stage yet (the kernel brings hardware up inline
in `kernel_main`). Until those exist, the capability probe runs at boot
(as it does today) and the eventual fast path re-reads per transfer. The
rule that holds now: the speed decision consults *freshly read* card data,
never a baked-in assumption.

### Stage 1 — 4-bit, High-Speed (board-voltage-independent, low risk)

The safe first speed-up, no voltage switch:
- **4-bit bus** — `ACMD6` SET_BUS_WIDTH to 4-bit, and set the DW MSHC
  `CTYPE` to 4-bit. 4× the data lanes at the same clock.
- **High-Speed (50 MHz)** — `CMD6` SWITCH_FUNC (mode 1, group 1 → High
  Speed), then set `CLKDIV` to 50 MHz. Default speed is 25 MHz; High
  Speed doubles it.

Together that's roughly an 8× jump (4-bit × 2× clock) over today's
1-bit/25 MHz — ~25 MB/s, at 3.3 V, with no tuning. This alone makes the
backup write side respectable and is the right first target.

### Stage 2 — UHS-I (only if the slot can switch to 1.8 V)

If the board has a switchable SD I/O rail:
- **Voltage switch** — `CMD11` VOLTAGE_SWITCH, then move the card and the
  host pads to 1.8 V signalling.
- **SDR50 / SDR104** — `CMD6` to the UHS mode the ceilings allow, set the
  DW MSHC UHS mode + 100/208 MHz via the SDMMC0_DRV / SDMMC0_SAMPLE phase
  shifters, and (SDR104) run a tuning pass (`CMD19` SEND_TUNING_BLOCK).

SDR104 tops the bus at ~104 MB/s; the card's write class is then the
floor. Higher risk (voltage switch + tuning), so it follows Stage 1.

### Relationship to the backup

The eMMC→SD backup is now a de-selectable probe (`emmc-backup`, off by
default — lifted out of the auto-boot flow this round). Today it runs the
legacy path both ways. Once Stage 1 lands, the same probe's SD writes go
through the fast path; the eMMC reads already can (110j). Then a
double-buffered / DMA copy (deferred, see below) overlaps the two so the
wall-clock collapses to the slow side — the SD write.

### Deferred (orthogonal)

- **DMA / double-buffering** the copy (so eMMC reads and SD writes
  overlap) — a throughput refinement on top of the bus speed, shared with
  the eMMC ADMA2 deferral in 110j.
- **The CPU clock.** Everything is currently ~35× slow because the CPU
  runs at the bootloader's ~50 MHz, not its rated 1.8 GHz (phase 2,
  201a). When that lands, even the legacy SD path speeds up hugely; UHS
  is still worth it for the ceiling, but the urgency is partly the slow
  CPU, not the slow bus.

## Suggested implementation steps

1. **Capability probe** (`sd_probe_capabilities`) — done; read-only.
   Flash it and read off SCR / SD_STATUS / SWITCH_FUNC to learn the
   card's ceilings 2 and 3, and confirm the FIFO byte order for the
   decode.
2. **Board-voltage check** — inspect the SDMMC0 device-tree node for a
   `vqmmc-supply`. Its presence (and which PMIC rail) decides whether
   Stage 2 is reachable at all.
3. **Dynamic speed select** — built directly as the picker, *not* a
   hardcoded stage (no sense building scaffolding we'd replace, and a fixed
   speed surfaces no debug information). Read the card's width and modes
   (SCR + the SWITCH_FUNC query) and weigh them against the host's ceiling
   at the current 3.3 V signalling (High-Speed; UHS needs the 1.8 V switch
   of step 5), log all the inputs, and apply the safe minimum: `ACMD6`
   4-bit + the DW MSHC `CTYPE`, then `CMD6` SWITCH_FUNC to High-Speed + a
   50 MHz `CLKDIV` when both sides offer it. Validate with the proven IDMAC
   write + PIO read round-trip *at* the new speed. For this card it lands
   on 4-bit High-Speed; the same min-of-ceilings logic reaches UHS for free
   once step 5 adds that ceiling.
4. **Wire the backup probe's SD writes through Stage 1** and re-run the
   `emmc-backup` probe; measure the new throughput.
5. **Stage 2** (if voltage allows) — `CMD11` 1.8 V, `CMD6` SDR50/SDR104,
   host UHS mode + phase shifters + tuning.
6. **DMA / double-buffer** the copy (deferred; with 110j's ADMA2).

## Related documents and tools

- `src/015-sdmmc.c` — the DW MSHC driver this extends; now carries the
  command machinery, the capability probe, and `sd_read_small`.
- `input/probes/sd-capabilities.probe` — the read-only capability dump.
- `input/probes/emmc-backup.probe` — the de-selectable backup that will
  route through the fast write path.
- `issues/110j-fast-emmc-hs200.md` — the eMMC fast read side (the other
  half of a fast backup); shares the DMA deferral.
- `issues/110f-microsd-controller-driver.md` — the SD controller bring-up
  this builds on.
- **Reference needed:** the DW MSHC UHS bring-up is not yet in
  `tmp/uboot-ref/` (that has the eMMC `rockchip_sdhci.c`, not the SD
  `dw_mmc.c` / `rockchip_dwmmc.c`). Extract the dw_mmc reference before
  Stage 2, the way the eMMC and i2c references were extracted.

## Blocked by

Nothing for Stage 1 — the SD controller (110f) is up and the capability
probe is built. Stage 2 is gated on the board-voltage answer (step 2) and
on extracting the dw_mmc UHS reference.
