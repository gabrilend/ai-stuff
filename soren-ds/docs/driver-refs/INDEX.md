# Reference driver sources

Upstream (Linux / u-boot) driver source for chip blocks the public RK3568
TRM omits or under-documents. When a peripheral's register map is not in
`docs/datasheets/` (the TRM), the vendor's own driver is the de-facto
specification — the same way the i2c and eMMC bring-ups leaned on u-boot
reference drivers. Kept here, in the repo (persistent), rather than under
`tmp/` (RAM-backed, wiped on reboot — which is why earlier `tmp/uboot-ref/`
copies vanished).

These are read-only references, not compiled into anything. Cite them the
way source comments cite the TRM (part + chapter): name the file + function.

## Files

- **`rockchip-otp.c`** — Rockchip OTP / eFuse driver (Linux
  `drivers/nvmem/rockchip-otp.c`). The RK3568 TRM has **no OTP-controller
  chapter** (only the address-map entry `OTP_NS 0xFE38C000` and the CRU
  clocks), so this driver is the only spec for the chip-ID read FSM.
  `rk3568_otp_read()` has the sequence: SBPI reset + ECC-enable preamble,
  then user mode (`OTPC_USER_CTRL` 0x00010001), then per 16-bit word write
  the address (`USER_ADDR` = offset | 0xFFFF0000) + enable (`USER_ENABLE`
  0x00010001), poll `INT_STATUS`(0x304) for `USER_DONE` (bit 2), read
  `USER_Q`(0x124). The RK3568 cpuid is 16 bytes at OTP word offset 0xa.
  Used by: `otp_probe` in `src/019-probe-engine.c` (presence read today;
  the full chip-ID FSM is the follow-up this file unblocks).

## How to add one

`curl -fsSL --create-dirs -o docs/driver-refs/<name>.c <raw-url>` — the raw
GitHub URL of the file in torvalds/linux or u-boot/u-boot. Then note it here
and cite it from the source comment that uses it. (Ghostscript reads the TRM
PDFs directly for the blocks that ARE documented:
`gs -sDEVICE=txtwrite -dFirstPage=N -dLastPage=M -sOutputFile=out.txt in.pdf`.)
