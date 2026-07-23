# 111c — JD9365DA-H3 panel initialization

## Current behavior

After 111b the DSI controllers and D-PHYs are alive in command
mode. The kernel can send MIPI DSI command packets to the
panels. But the panels themselves are still in their reset
state and will not accept pixel data until their internal
register sequence has been programmed.

**Implemented (2026-07-02) in `src/023-mipi-panel.c`.** `panel_init_all()`
resets each panel (GPIO0_B3 bottom / B4 top), replays the JD9365 DCS init
table in low-power mode, then sends Sleep-Out and Display-On, for both
panels. The 203-command init table was **extracted from the board device
tree's `panel_description`** (not hand-typed — see `tmp/extract-panel-seq.lua`);
the two panels differ by exactly one byte (register 0x37), handled as a
per-panel override. The command-FIFO registers + low-power `CMD_MODE_CFG`
(TRM Part2 Ch29) and the GPIO reset registers (TRM Part1 Ch16) are all
TRM-verified; the one flagged assumption is the DCS-vs-Generic data type for
the register writes (using DCS short-write 0x15, the mainline convention).
Compile-verified, not yet wired into boot. **Deferred to 111d:** the
command-mode → video-mode switch, because it needs the video timing (the
panel porch numbers, whose field order is still being confirmed) — so this
file leaves the panel initialized but the host still in command mode, rather
than guess the timing.

The Jadard JD9365DA-H3 datasheet specifies a long table of MIPI
DSI command writes — typically dozens of register writes — that
configure the panel's internal logic, gamma curves, gate driver
timing, source driver timing, power control, and so on. Without
this sequence, the panel ignores pixel data; with it, the panel
displays whatever VOP2 sends it.

## Intended behavior

Both panels receive their full initialization sequence over
their respective DSI lanes. After this issue closes:

- The bottom panel's JD9365DA-H3 has been driven through its
  reset pulse (per the panel reset GPIO from
  `docs/014-hardware-overview.md` — GPIO0 PB3 for the bottom),
  then sent the full DSI initialization register sequence,
  then sent the Sleep Out command and the Display On command.
- The top panel goes through the same sequence on DSI1 with
  its reset GPIO (GPIO0 PB4).
- Both DSI controllers are switched from command mode to video
  mode at the end of the sequence; they will now stream the
  pixel data VOP2 sends them once a framebuffer is configured.
- Bring-up status flows through the CDC-ACM debug stream so
  each panel's progress is visible.

After this issue closes the panels are ready to display pixels
but no framebuffer is configured yet, so they are showing
whatever the panel's default scan-out is (typically all-black or
the panel's own boot screen). 111d allocates framebuffers and
points VOP2 at them.

## Pulling the initialization sequence

The JD9365DA-H3 register sequence is documented in the panel's
datasheet, which we do not yet have. The upstream Linux driver
at `drivers/gpu/drm/panel/panel-jadard-jd9365da.c` carries the
sequence as a const array of MIPI DCS commands. The most
practical path is to copy the sequence from the upstream driver
and translate the Linux MIPI-DCS macros into our own equivalent
helpers.

The sequence is identical between the two panels — same panel
part, same orientation, same configuration — so the same
sequence sends to both. Each panel just has its own DSI lane
and its own reset GPIO.

## Suggested implementation steps

1. Pull the panel init sequence from
   `drivers/gpu/drm/panel/panel-jadard-jd9365da.c` in upstream
   Linux. Translate the MIPI-DCS macros into a flat table of
   `(reg, value)` pairs the kernel can iterate over.
2. Write a small helper that sends a single MIPI DCS write
   through a given DSI controller by composing the DSI packet
   header, the command byte, the parameter bytes, and pushing
   the lot through the controller's command FIFO.
3. Write a reset pulse helper that drives the panel reset GPIO
   low, waits the documented hold time, drives it high, waits
   the documented settle time.
4. Implement a `panel_init` function parameterized on
   `(dsi_controller_base, reset_gpio_bank, reset_gpio_bit)`.
   Call it once per panel.
5. After the init sequence completes, switch the DSI controller
   from command mode to video mode.
6. Narrate progress through CDC-ACM at major milestones (reset
   pulse done, init table sent, sleep-out done, display-on
   done, video mode entered).

## Related documents

- `docs/014-hardware-overview.md` — panel IC and reset GPIOs.

## Blocked by

111b, 110.

## Blocks

111d.

## Parent

111.
