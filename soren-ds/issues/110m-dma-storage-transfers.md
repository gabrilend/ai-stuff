# 110m — descriptor-driven (DMA) storage transfers

The throughput half of fast storage, and the thing that makes a **full
eMMC dump** practical. The speed *modes* are done (110j: HS200/HS400 read
proven) and the SD fast-write path is filed (110l), but every transfer
still moves through the CPU one word at a time. For a multi-GB dump of the
whole eMMC onto the SD card (to pull and examine on the dev machine —
expected mostly zeroes), that CPU copy is the wall.

## Current behavior

Both DMA engines are built and proven on hardware, and together they carry a
working **full eMMC dump**, captured and verified end to end:

- **eMMC ADMA2 multi-block read** (`emmc_read_blocks_dma`, `src/012-emmc.c`)
  — reads 128 blocks (64 KB) per call; the DMA fingerprint matches the PIO
  path at legacy, HS200, and HS400.
- **microSD IDMAC multi-block write** (`sd_write_blocks_dma`,
  `src/015-sdmmc.c`) — one `CMD25` writes a whole run described by a *chain*
  of descriptors (each ≤ 8 KB, the 13-bit BS1 limit), with the controller's
  auto-stop sending the trailing `CMD12`. Validated by a 24-block (three
  chained descriptors) write read back through PIO.
- **Full linear dump** (`emmc_dump_to_sd`) — copies every sector of the card
  to the SD's dump region in order, eMMC sector N → SD `DUMP_DEST_LBA + N`.
  No map and no zero-skipping: the dev side simply concatenates the pulled
  pieces, so nothing has to be reconstructed and nothing can tear across a
  log flush. It moves the whole card (~29 GiB, zeros and all), so it is
  gzip-compressed on the way off the SD (the ~75% zeros collapse to almost
  nothing). Its one machine-parsed line — the `complete total=… packed=…`
  summary — is built into a single buffer and emitted with one `debug_write`
  so it, too, cannot tear.
- **Layout recon** (`emmc_scan_map`) — a separate read-only pass that logs
  the non-zero LBA ranges (block-level run-length encoding) without writing
  gigabytes, for when the card's real layout is wanted cheaply. It no longer
  drives the dump.
- **Pull + archive** — `scripts/lab-side/dump-from-sd` reads the dump region
  back off the SD, gzips it, and splits the stream into < 4 GiB pieces (a
  FAT32 USB drive caps files at 4 GiB). The dev side reassembles with
  `cat pieces | gunzip` — no MAP replay. `scripts/lab-side/reconstruct-emmc`
  is retained for the optional sparse path, keeping its torn-record-skip
  parse and integrity cross-check.

The first full dump has been pulled and verified end to end: the gzip stream
tests clean (CRC + length), and it decodes to the card's real 15-partition
factory GPT (`security`/`uboot`/`trust`/…/`super`/`userdata`).

Still deferred: double-buffering (overlap read run N+1 with write run N), a
throughput readout, the eMMC ADMA2 *write-back* path, and the caches/MMU
work that would make even the PIO paths fast. Until caches come on, the CPU
runs near 800 MHz but stalls on DRAM every instruction (201a recon) — which
is why DMA, keeping the CPU out of the copy loop, matters now.

## Intended behavior

Hand the controllers a **descriptor** — "move N bytes to/from this
address" — and let each one move the data on its own while the CPU waits
(or, later, does other work). The copy then runs at *bus* speed, not CPU
speed, and the caches-off penalty on the copy disappears (the CPU isn't in
the inner loop). Two different DMA engines, one per controller:

- **eMMC (SDHCI) → ADMA2.** The SD Host Controller standard's Advanced DMA
  v2: a table of `{attributes, length, address}` descriptors the
  controller walks. Set the host-control DMA-select to ADMA2, point the
  ADMA address register at the table, enable DMA in the transfer mode, and
  issue a multi-block command (`CMD18` read / `CMD25` write). The
  controller bursts the whole run. The eMMC's CAPABILITIES advertises
  ADMA2 (bit 19 set on this part), so it's available.
- **microSD (DW MSHC) → IDMAC.** The DesignWare controller's *internal*
  DMA controller, a different descriptor format and its own
  enable/bus-mode/descriptor-base registers (BMOD, DBADDR, IDSTS). Same
  idea, different plumbing.

Coherency is free here, unusually: with the MMU and caches off (phase 1),
DMA writes land in DRAM and the CPU reads DRAM directly — no cache flush
or invalidate needed. (This must be revisited when caches come on: the
buffers will then need flush-before-write / invalidate-after-read.)

### The driving use case — getting the entire eMMC onto the dev machine

The point is to get the **entire eMMC** onto the dev machine to examine it.
Two shapes were built. The **plain full copy** (every sector eMMC→SD in
order, no map) is what shipped: it moves all ~29 GiB but has nothing to
reconstruct and nothing to corrupt. A **sparse** variant was also explored —
copy only the non-zero 64 KB chunks packed end to end, plus a MAP (one record
per run, `orig` eMMC LBA → `packed` SD LBA + `len` sectors, block-level
run-length encoding) that `reconstruct-emmc` replays into a sparse image.

The sparse variant was parked in favour of the full copy, for the reason the
next reader should keep in mind: the sparse trick only saves *transfer time*
(~7 GiB vs 29 GiB over the slow SD write). It does **not** shrink the archive
— gzip collapses the zeros of a full dump just as well — and a card big enough
for the full dump needs no map at all. The plain full copy is simpler and has
no map to corrupt (see the tearing lesson below, which is what settled it);
prefer it unless transfer time is the real constraint.

### Lesson: a machine-parsed log record must be one `debug_write`

The MAP rides through the SD-backed debug log (`src/017-debug-log.c`), a
4 KB RAM ring that flushes to the card at 75% full and zero-pads the page
tail. A MAP record emitted as several `debug_write` calls (label, hex,
label, hex, …) could have that flush fall *between* the calls, splitting the
record across two zero-padded pages; `strings(1)` on readback then treats
the zero gap as a line break and the record comes back torn in two. 10 of
742 records tore this way and the reconstruction lost them. The rule that
settled it: any machine-parsed line is built into one buffer and emitted with
a **single** `debug_write` — a ≤ 61-char string can't cross the 4 KB page
(`log_buffer_pos` is always < 3072 at the start of a write), so a flush can
only land at the trailing newline, between records. This is why the shipped
dump is the linear copy — its sole parsed line, the `complete …` summary,
follows the rule — rather than the sparse one; the sparse MAP emitter must
obey the same discipline for every record if it is ever re-enabled.
`reconstruct-emmc` additionally skips any malformed record and cross-checks
the surviving count against the dump's own `ranges=`/`packed=` summary, so a
torn map is *reported loudly*, never silently under-filled.

### microSD IDMAC — distilled from the RK3568 TRM (section 6.3.3)

No external driver needed: the TRM documents the DW MSHC's internal DMA
engine in full. The pieces to build step 3 from:

- **Descriptor** (chain mode, 32-bit bus): 16 bytes = four 32-bit words.
  - `DES0` (control): bit31 OWN (1 = IDMAC owns it, it clears OWN when
    done), bit5 ER (end of ring), bit4 CH (chained — `DES3` is the *next
    descriptor* address, not a 2nd buffer), bit3 FS (first), bit2 LD
    (last), bit1 DIC (disable completion interrupt); bit30 CES mirrors the
    error bits.
  - `DES1`: BS1 (bits 12:0) = buffer-1 byte size — **13 bits, so ~8 KB max
    per descriptor**, so big transfers chain many (the dump links a lot).
    BS2 (25:13) = 0 in chain mode.
  - `DES2`: buffer-1 physical address.
  - `DES3`: next-descriptor address (chain mode).
- **Registers** (DW MSHC CSR, 0x80–0x98): `CTRL` bit25 = enable IDMAC
  (USE_INTERNAL_DMAC); `BMOD @0x80` = bus mode (bit0 SWR reset, bit1 FB
  fixed-burst, bit7 DE DMA-enable, bits10:8 PBL burst, bits6:2 DSL);
  `PLDMND @0x84` = poll demand (un-suspend the engine); `DBADDR @0x88` =
  descriptor-list base; `IDSTS @0x8C` = status; `IDINTEN @0x90` =
  interrupt enable.
- **Init**: software-reset the IDMAC (BMOD SWR), program BMOD, mask
  interrupts (IDINTEN — we poll), build the descriptor list with OWN set,
  write its base to DBADDR, enable via CTRL bit25 + BMOD DE, then issue the
  read/write command. Completion is DATA_OVER + the IDSTS TI/RI bit; errors
  land in IDSTS and the descriptor's CES.
- **Coherency**: same as the eMMC side — free while caches are off, must be
  revisited when they come on.

## Suggested implementation steps

1. **eMMC ADMA2 read** — a multi-block read (`emmc_read_blocks_dma`),
   validated by fingerprint-matching the PIO path at legacy, HS200, and
   HS400. *(Done.)*
2. **microSD IDMAC multi-block write** — `sd_write_blocks_dma`: one `CMD25`
   over a chain of ≤ 8 KB descriptors + auto-stop, built from the TRM 6.3.3
   distillation below. Validated by a 24-block (three-chain) write read back
   through PIO. *(Done — the write direction is all the dump needs.)*
3. **Full linear dump** — `emmc_dump_to_sd`: copy every sector to the SD dump
   region in order (eMMC N → `DUMP_DEST_LBA + N`), no map, with the one
   `complete …` summary line emitted atomically. This is the shipped dump —
   proven end to end (pull → gzip verify → factory GPT decodes). A sparse
   MAP variant was explored and parked (see the driving-use-case and tearing
   notes above). *(Done.)*
4. **Pull + archive toolchain** — `dump-from-sd` reads the dump region back,
   gzips it, and splits into < 4 GiB FAT32-safe pieces; the dev side does
   `cat pieces | gunzip`. `reconstruct-emmc` (MAP replay + torn-record-skip +
   integrity cross-check) is retained for the optional sparse path. *(Done.)*
5. **eMMC ADMA2 write-back** — `CMD25` multi-block write on the *eMMC* side,
   for writing images back to the card later. *(Deferred.)*
6. **Double-buffer + throughput** — read run N+1 while writing run N to
   overlap the two engines, and a `CNTPCT` timer so the dump reports MB/s
   instead of a guess. *(Deferred.)*

## Related documents and tools

- `src/012-emmc.c` / `src/015-sdmmc.c` — the two drivers gaining DMA.
- `issues/110j-fast-emmc-hs200.md` — the eMMC speed modes the DMA read
  rides on; this is the ADMA2 deferral that issue named.
- `issues/110l-fast-sd-uhs.md` — the SD fast-write side; the dump's write
  half needs both this and the IDMAC engine.
- `issues/201a-cpu-clock-bring-up.md` — why PIO is so slow now (caches off
  more than clock); DMA sidesteps it for the copy.
- The microSD IDMAC reference is the RK3568 TRM section 6.3.3 (we have it
  as text under `tmp/datasheet-text/`); the relevant bits are distilled
  into this issue above, so no external driver extraction is needed.

## Blocked by

Nothing — the eMMC controller advertises ADMA2 and the fast read modes are
proven (step 1), and the microSD IDMAC is fully documented in the TRM (step
3 reference resolved and distilled above).
