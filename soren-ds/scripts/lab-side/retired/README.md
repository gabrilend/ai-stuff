# Retired — superseded SD-card probe tooling

These scripts delivered the hardware-probe battery to the device by
writing it onto reserved microSD regions *after* flashing:

- `flash-sd`'s old `load_probe_catalog` (now gone from `flash-sd`)
  wrote the whole library plus a run-all marker onto the card.
- `select-probe` activated one probe, or re-armed the sweep, by
  rewriting the card's active region.
- `write-probe` pushed a single ad-hoc probe script to the card.
- `probe-common.sh` held the shared LBA constants and the
  `SPRB`/`SPRA`/`SPCT` header builders the other two relied on.

They were retired when the probes moved in-tree: a
`scripts/build --probes` build now compiles every
`input/probes/*.probe` into the kernel and runs them all on boot, so
nothing probe-related is written to the card. The card delivery was
abandoned for two reasons — it fought the lab laptop's automounter
(modern kernels refuse a whole-disk write while a partition is
mounted, and the automounter kept re-mounting the freshly-flashed
card between writes), and, once a build flag is accepted as the
trigger, a rebuild is already happening, so the "change a probe
without rebuilding" benefit the interpreter existed for was moot.

Kept for reference only; `push-to-usb` excludes this directory, so it
is never synced to the lab drive. The full story and the exact on-card
format live in issue 110i.
