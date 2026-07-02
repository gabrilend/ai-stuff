# archives/ — known-good factory captures

Snapshots of the stock device pulled off real hardware and kept as
restore images and as the raw record behind the docs. This directory is
the answer to the bricking doc's standing rule: *always keep a known-good
boot image we can revert to* (`notes/safety/000-bricking-and-recovery.md`,
Summary recommendation).

## What's here — the 2026-07-01 factory pull

Pulled via the compiled-in `emmc-dump` probe (`src/012-emmc.c`
`emmc_dump_to_sd`), carried off the microSD by
`scripts/lab-side/dump-from-sd`, and copied here from the lab flash drive
(`/mnt/generic/lab-output/`). This run was a **full linear** dump
(`[dump] complete total=packed=0x03A3E000`, no sparse MAP), so the gzip is
just the whole card end to end.

| File | Size | In git? | What it is |
| ---- | ---- | ------- | ---------- |
| `bootchain-20260701-130529.bin.gz` | 2.7 MB | **yes** | the first 16 MiB of the card (GPT + security + uboot + trust), gzipped — the restore image for the partitions we otherwise never touch |
| `bootchain-20260701-130529.bin.gz.sha256` | — | **yes** | checksum of the slice |
| `emmc-20260701-130529.img.gz.00` | 3.0 GiB | no (gitignored) | first half of the gzipped full-device dump |
| `emmc-20260701-130529.img.gz.01` | 1.98 GiB | no (gitignored) | second half |
| `debug-log-20260701-130529.img` | 16 MiB | no (gitignored) | raw SD-backed kernel debug-log region |
| `probe-*-20260701-130529.log` | KB each | no (monorepo `*.log`) | per-probe on-device results, split out of the debug log |

Only the small boot-chain slice, its checksum, and this manifest are
version-controlled. The 5 GiB full dump and the logs live on disk here and
on the lab flash drive — two copies — but out of git. The measured values
from the probe logs are folded into `docs/014-hardware-overview.md`.

## The committed boot-chain slice

`bootchain-20260701-130529.bin.gz` is LBA 0–32767 of the eMMC: the
protective MBR + GPT, then partitions 1–3 (security / uboot / trust),
ending exactly where `misc` begins. It is the raw Rockchip boot chain the
BootROM and u-boot load, and the only committed copy of **Anbernic's own
bootloader**. Raw (ungzipped) SHA-256:
`8141633f7079966fae762faa8ac6412b7a1474d3807ce05cb31218d595968d87`.

Disk GUID `F808D051-1602-4DCD-9452-F9637FEFC49A` — matches
`docs/024-emmc-partition-map.md`, so this is the same unit that map was
read from. What the bytes say about the boot chain:

- **U-Boot SPL 2017.09-g606f72bd97a-240527 (built 2024-05-30), fwver
  v1.14** — a stock Rockchip vendor u-boot (the 2017.09 vendor fork), on
  the generic `rk3568-evb` control device tree, not a board-specific one.
- Chains **ARM Trusted Firmware (BL31) + OP-TEE** — the `trust` partition.
- u-boot proper and the trust payload are FIT-packed/compressed, so only
  the SPL banner and the FIT control DTB show up in `strings`.

## Reconstructing / inspecting the full image

This dump is linear, so no MAP replay is needed:
`cat emmc-*.img.gz.* | gunzip` streams the full ~29 GiB card in LBA order
(sector 0 first). To carve a region without materialising 29 GiB, pipe
through `head -c` / `dd`:

    cat archives/emmc-20260701-130529.img.gz.* | gunzip | head -c 16777216 > bootchain.img   # LBA 0..32767

(The `scripts/lab-side/reconstruct-emmc` MAP-replay path is only for the
*sparse* dump variant; this pull isn't one.)

## Provenance

- Device: the stock Anbernic RG DS, unmodified (not re-flashed since).
- Layout reference: `docs/024-emmc-partition-map.md`.
- Recovery role: `notes/safety/000-bricking-and-recovery.md`.
