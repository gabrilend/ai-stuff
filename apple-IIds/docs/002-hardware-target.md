---
name: hardware target
status: pinned (2026-05-19) — Anbernic RG DS
---

# hardware target

The target platform is the **Anbernic RG DS**, a dual-screen ARM handheld
in DS-like form factor. This document captures what is known from the
vendor spec sheet (https://anbernic.com/products/rgds) plus what is known
from user inspection of the device itself.

## confirmed specs (vendor spec sheet)

| property                  | value                                              |
|---------------------------|----------------------------------------------------|
| SoC                       | Rockchip RK3568                                    |
| CPU                       | Quad-core 64-bit ARM Cortex-A55 @ 2.0 GHz          |
| GPU                       | ARM Mali G52 2EE                                   |
| RAM                       | 3 GB                                               |
| internal storage          | 32 GB                                              |
| expandable storage        | microSD up to 2 TB                                 |
| top panel                 | 4″ IPS, 640×480, OCA full lamination, multi-touch, stylus |
| bottom panel              | 4″ IPS, 640×480, OCA full lamination, multi-touch, stylus |
| audio out                 | stereo speakers + 3.5 mm jack                      |
| WiFi                      | 802.11 a/b/g/n/ac, 2.4/5 GHz                       |
| Bluetooth                 | 4.2                                                |
| OS shipped                | Android 14 / Linux 64-bit (we use Linux)           |
| battery                   | 4000 mAh polymer lithium, ~6 h runtime             |
| weight                    | 321 g                                              |
| dimensions                | 160 × 91 × 21.5 mm                                 |
| extras                    | six-axis gyro, vibration motor, Hall sleep switch  |

## confirmed controls (user inspection)

The vendor page omitted the control layout. Confirmed by gabrilend on
2026-05-19:

| input                | count | notes                                       |
|----------------------|-------|---------------------------------------------|
| analog sticks        | 2     | both clickable (L3 / R3 equivalent)         |
| d-pad                | 1     | left side                                   |
| face buttons         | 4     | right side (presumably A, B, X, Y)          |
| L shoulder           | 2     | L1, L2                                      |
| R shoulder           | 2     | R1, R2                                      |
| Start                | 2     | one on right side, one on bottom-left       |
| Select               | 2     | one on right side, one on bottom-left       |
| volume               | 2     | up / down                                   |
| power                | 1     |                                             |
| USB-C ports          | 2     | one labeled "DC/USB", one labeled "OTG"     |

The duplicated Start / Select pairs are interesting and load-bearing: they
let us assign each screen its own Start and Select without ever sharing
buttons. The bottom-left pair belongs to screen B; the right-side pair
belongs to screen A (provisional convention).

The two USB-C ports likely behave as: **DC/USB** = primary charging +
host-mode data; **OTG** = device-mode (so the handheld can present itself
to a desktop computer as a USB peripheral). To be confirmed with the
device in hand — this is convenient for development (we ssh in via the
host-mode port and the handheld can also act as a USB drive on demand).

## native screen mapping

The Apple IIgs Super Hi-Res framebuffer is **320×200**. Each RG DS panel
is **640×480**. The mapping is exact:

- **2× integer scale to 640×400**, centered vertically with **40 pixels of
  letterbox above and 40 below** (or 80 pixels reserved at the bottom
  for a thin broker-drawn status strip and the radial-keyboard overlay).

No bilinear filtering, no aspect distortion. The "Centered integer scale"
strategy from the original Mac Plus plan is now the only sensible
strategy — no other scale ratio is integer.

The IIgs also has older video modes (40-column text, 80-column text, lo-res
40×48, hi-res 280×192 with NTSC artifacting, double hi-res 560×192). These
all need scaling decisions:

- 40-column text (40×24 chars, 280×192 pixels) — scale 2× to 560×384,
  letterboxed
- 80-column text (80×24 chars, 560×192 pixels) — scale 1× to 560×192 with
  large letterbox, or vertical 2× to 560×384 (squishes characters)
- Super Hi-Res (320×200) — 2× to 640×400, 80 px letterbox

The cleanest answer is: **always scale the IIgs framebuffer by 2× and
center**, regardless of the IIgs video mode. The IIgs hardware itself
upsamples lower-res modes into the same 640×400 effective output during
NTSC scan-out, so doing it in our framebuffer path mirrors what the real
machine did.

## input device assumptions for layer 2

The radial dual-stick keyboard (see `003-input-system.md`) assumes:

- both sticks report a continuous (x, y) vector (RK3568-driven analog
  sticks typically do; to be confirmed once we read raw `/dev/input/eventN`)
- the broker performs the quantization to N-direction wedges
- a stick at rest reports a vector within a dead-zone we control

## what to confirm with the device in hand

- Linux `/dev/input/eventN` mapping for each control (which event device
  exposes which buttons / sticks / touch panels).
- Exact `/dev/fb*` device(s) for each panel; whether they are accessed via
  DRM/KMS or legacy framebuffer.
- Whether the IPS panels support 60 Hz cleanly, or some other refresh.
- The two USB-C port semantics (DC/USB vs OTG) in practice — does host-mode
  work over either, or only DC/USB?
- Stylus detection: does the digitizer report stylus vs finger separately?
  (Useful for the right-click equivalent: stylus tap = click, finger tap
  = click, but stylus-with-button-held = right-click.)
- Whether the gyroscope is exposed as a Linux IIO device and what its
  precision is.

These open questions are tracked in issue `101-source-and-toolchain.md`
(phase 1).
