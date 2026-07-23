# Conversation Summary: fb1cb658-a1cb-4e46-aa80-533463ce31cf

Generated on: 2026-07-11 21:58:54

--------------------------------------------------------------------------------

### User Request 1

Hi, we're having trouble getting our custom OS to boot on the device. Can you
look at the existing community OS implementations (and the official Anbernic
Linux OS) and tell me what we're doing differently? How do they get the system
to boot?


--------------------------------------------------------------------------------

### Assistant Response 1

I'll look around the project first to understand what device/setup you're
working with, then research the community and official boot chains to compare.


I have a good picture now: this is SoreOS for the Anbernic RG DS (RK3568),
trying to boot via ROCKNIX's idbloader + u-boot, loading the kernel through
extlinux. Let me check the latest boot-debugging work and current kernel entry
code before dispatching research.


I have a clear picture: they boot via ROCKNIX's idbloader + u-boot + extlinux,
the kernel lives at /KERNEL on a FAT32 partition labeled "ROCKNIX", they've
moved the load address to 0x02000000 and added an ARM64 header with the
"ARM\x64" magic. But they've never seen the LED probe wink — which is
suspicious. Let me dispatch a research agent to compare against the community
OSes.


The research agent hit a server error. Let me check what tools I need to
continue it.


The earlier agent is gone. Let me split this into two parallel research agents
— one to inspect the actual ROCKNIX image bits we use, and one to research the
other community OSes via the web.


Server's having trouble with sub-agents. Let me do the research directly.
Starting with the u-boot FIT we already have on disk and the upstream community
OS configs.


This is a huge clue: the u-boot we ship explicitly sets
`kernel_addr_r=0x02000000` (matches our linker pin), but uses the modern
`bootflow scan -lb` rather than the older `distro_bootcmd` path. Let me dig
deeper.


The u-boot environment confirms `kernel_addr_r=0x02000000` matches SoreOS's
linker pin. Both extlinux and boot.scr paths exist. Let me try one more agent
dispatch for the kernel image inspection, and meanwhile look at the actual
ROCKNIX extlinux conf they copied locally.


Plenty of space. Let me try the agent again, and also kick off the download in
parallel since the agent retries may keep failing.


Download complete (1.4 GB). Decompressing and inspecting the FAT partition now.


ROCKNIX's KERNEL is 29.6 MB (full Linux kernel). Let me grab its format and the
extlinux.conf, plus check for boot.scr.


ROCKNIX's KERNEL format matches SoreOS's exactly (same magic, same flags=0x0a).
Let me check SoreOS's actual built kernel header to verify the bytes match.


Big realization — let me verify how the linker pins the kernel. _start is at
byte 64 of the image, so the image header must be at 0x02000000 and _start at
0x02000040.


Let me compare SoreOS's actual generated SD image FAT contents against ROCKNIX's
directly.


Let me verify the FAT-copied KERNEL in SoreOS's image actually matches the
source kernel.img, and clean up the ROCKNIX research image.


Boot chain pieces are byte-identical to ROCKNIX through the entire pre-u-boot
stage. Let me verify the PMU_GRF and GPIO0 addresses our LED probe uses against
the actual device tree.


Cleaning up the giant research files, then writing up findings.


Here's what I found by comparing your boot setup against ROCKNIX's actual
shipping image and the u-boot you reuse from it.


## What's identical (i.e. not your problem)


**Pre-u-boot boot chain** — byte-for-byte identical to ROCKNIX. The Rockchip BootROM reads sector 64, finds the same RKNS-magic idbloader, brings up DRAM, hands to u-boot. The u-boot.itb you splice in at sector 16384 is the same FIT ROCKNIX ships (one u-boot, five ATF/BL31 variants). Nothing diverges from ROCKNIX through this layer.


**Kernel-image format**. I extracted ROCKNIX's `/KERNEL` and compared to your `output/kernel.img`. Both start with the same NOP + branch-to-_start pair, both carry the same `flags = 0x0a` (little-endian, 4 KiB pages, placement-flexible), both have the `"ARMd"` magic at offset 56, both are flat uncompressed arm64 Linux Images. Theirs is 29 MB of real kernel; yours is 15 KB; structurally they're the same envelope.


**Load address**. I pulled the u-boot environment defaults straight out of the FIT. `kernel_addr_r=0x02000000` — exactly the address your linker pins `__image_start` to. So when u-boot's extlinux loader reads `/KERNEL` and copies it to `kernel_addr_r`, the byte at offset 64 (your `_start`) lands at 0x02000040, and the literal-pool addresses the linker baked in resolve correctly.


**FAT layout**. Volume label `ROCKNIX` ✓, `/KERNEL` at root ✓, `/device_trees/rk3568-anbernic-rg-ds.dtb` ✓ (and the DTB is byte-identical to the one ROCKNIX ships), `/extlinux/extlinux.conf` at root ✓. MBR partition table, FAT32 LBA type 0x0c, bootable flag ✓.


**Peripheral addresses in the LED probe**. The DTB confirms PMU GRF lives at `0xfdc20000` (your probe writes `0xfdc20014` — the GPIO0C iomux high register) and GPIO0 lives at `0xfdd60000` (your probe writes `0xfdd6000c` for DDR_H and `0xfdd60004` for DR_H). Bit positions for C4/C5/C6 are right too. If your kernel reaches `_start`, the LEDs *will* wink.


## What's different


| | ROCKNIX | SoreOS |

| --- | --- | --- |

| `extlinux.conf` | no `DEFAULT` line | `DEFAULT Soren` line |

| LABEL name | `ROCKNIX` | `Soren` |

| `APPEND` cmdline | `boot=LABEL=ROCKNIX disk=LABEL=STORAGE quiet
console=ttyS2,1500000 console=tty0 systemd.debug_shell=ttyS2` | absent |

| Other FAT files | `SYSTEM` (1.3 GB squashfs), `KERNEL.md5`, `SYSTEM.md5`,
`overlays/*.dtbo` | none |

| DTB in extlinux | default points to Powkiddy X55 (user edits to RG DS
post-install) | already RG DS |

| Bootloader-side env | `bootcmd=bootflow scan -lb` (modern bootstd, *not*
legacy `distro_bootcmd`) | — same u-boot — |


None of those plausibly explain a kernel that never reaches its first
instruction, but a few of them deserve scrutiny.


## Where I'd look next, in priority order


1. **Make your `extlinux.conf` structurally identical to ROCKNIX's.** Drop the
`DEFAULT` line, rename `LABEL Soren` → `LABEL ROCKNIX`, and add a placeholder
`APPEND console=ttyS2,1500000` line. Your kernel ignores cmdline, but u-boot's
pxe/syslinux parser may treat a label with no APPEND as malformed and refuse to
boot. Five-minute test, falsifiable.


2. **Sidestep extlinux entirely with a `boot.scr.uimg`.** Modern Rockchip
u-boots use `bootflow scan -lb`, which tries `bootmeth_script` *before*
`bootmeth_extlinux`. Drop a u-boot script at the FAT root:

```

load mmc 0:1 ${kernel_addr_r} /KERNEL

load mmc 0:1 ${fdt_addr_r} /device_trees/rk3568-anbernic-rg-ds.dtb

booti ${kernel_addr_r} - ${fdt_addr_r}

```

wrapped with `mkimage -A arm64 -O linux -T script -C none`. If this boots and
extlinux doesn't, you know it's the parser. If neither boots, the failure is
downstream — booti rejecting the image, or the jump landing somewhere
unexpected.


3. **Buy yourself a visible signal between u-boot and the kernel.** Add `gpio
set ...` commands to that `boot.scr` to drive one LED high *before* `booti`
runs. If you see that one LED but never the wink, the kernel image is being
rejected by booti and you'd see the diagnostic on the UART you don't have access
to.


4. **Take the wait-loop seriously.** Issue 103e's probe uses a `0xC000_0000`
busy-wait counter. At 1.8 GHz that's ~1.8 s; at the BootROM-handoff 24 MHz it's
>2 minutes. If u-boot is leaving the CPU at the lower freq, the wink is
happening but you're not waiting long enough. Sit for three solid minutes after
a flash before declaring no-LED.


5. **Cross-check with KNULLI's image** (the
`knulli-rk3568-rg-ds-scarab-*.img.gz` build). They build their own u-boot. If
their kernel format or extlinux differs from ROCKNIX's, that's evidence for what
u-boot quirks each side designs around. I didn't get that far before the
comparison answered the structural question — happy to do it as a follow-up if
(1) and (2) above don't unstick things.


Big picture: through u-boot's handoff to `booti` your setup matches a
known-working ROCKNIX byte-for-byte everywhere it can. The remaining suspects
are all on the `booti`-or-after side, and the cheapest test is a `boot.scr` that
does its own GPIO write before invoking booti so you can split "u-boot ran" from
"kernel ran" without a UART.


Sources:

- [Rocknix installation + setup on Anbernic RG DS (gist)](https://gist.github.com/ggtylerr/75750b7b26627d6b9cd95edf12b6b92d)

- [ROCKNIX distribution repo](https://github.com/ROCKNIX/distribution)


--------------------------------------------------------------------------------
