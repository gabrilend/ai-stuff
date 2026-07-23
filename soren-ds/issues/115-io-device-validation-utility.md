# 115 — interactive I/O device validation utility

Realized as the **first chip-script** ("chip") — the interactive-tool
category introduced in issue 116. That issue brings up the two things this
utility cannot exist without: a **console read path** (so a chip can hear the
developer's answer, not just narrate at them) and a reusable **menu**
primitive and **chip registry** to hang the device tests on. This issue is
the first tool that stands on that foundation; read 116 first for the machine
this plugs into.

A human-in-the-loop counterpart to the probe battery. The probes
(110i/110k/110n) are *fire-and-log*: they read registers, fingerprint
data, and write machine-verifiable results to the SD log. That model
cannot answer the questions that only a person can: *did the screen
actually show the pattern? did the tone come out of the speaker? did the
motor buzz? did the button I pressed register as the right one?* Those
need a device to produce an output and a human to confirm it — an
interactive utility, not a logged sweep. This issue is that utility.

## Current behavior

There is no interactive I/O validation. Output-device confidence today is
indirect: the LED layer proves the indicator lights, the probes read a
display controller's version register or dump the audio codec's registers
over i2c, but nothing drives a device and asks the developer whether the
*human-observable* result appeared. Input is unvalidated end-to-end —
there is no way to press a button and watch it register, or to see which
physical control maps to which event.

The recon that *has* been gathered (by probes and device-tree reading), so
the implementer starts with the register targets in hand:

- **Rumble** — the board has a vibration motor, PWM-driven. The
  `rocknix-singleadc-joypad` device-tree node references it as its
  "enable" PWM: `pwm@fe700020` — the **PWM3 controller block, 3rd
  channel** (register window `0xFE700020`, alias `pwm14`), period ~100 µs
  (~10 kHz). Bring the PWM3 block up the same way the LED layer brought up
  PWM1 (ungate its clock, release its reset, mux the pin — see
  `src/003-pwm.c` `led_pwm_init` for the pattern), then drive that
  channel's duty.
- **Audio** — the codec is integrated in the RK817 PMIC, reachable over
  i2c0 (up). The temporary `audio-codec` probe dumps its i2c register
  space; playing a tone additionally needs the I2S controller brought up
  and the RK817 datasheet to decode the codec registers.
- **Display** — the VOP2 controller's presence is confirmed by the
  `display-presence` probe (version register). Showing a test pattern
  needs the full display bring-up (111a–111d) to provide a framebuffer.
- **Buttons / sticks** — the `rocknix-singleadc-joypad` node: the
  face/D-pad buttons and the four analog channels come through a
  4-way ADC mux (`amux-*-gpios`, `io-channels`), plus a `HOME` button on
  the ADC-keys channel. The input drivers (phase 5, issues 501–504) read
  these.

## Intended behavior

One interactive utility that exercises every I/O device and gets a
human verdict, run on the device (results also echoed to the SD log / the
USB console when up). It covers both directions:

**Output devices — drive, then ask "did you observe it?":**

- **Display** — paint a known test pattern (colour bars, a moving marker,
  or a full-screen colour cycle) on each screen; ask the developer to
  confirm each screen shows it. Also ramp the backlight so a dark-but-alive
  panel is distinguishable from a dead one.
- **Audio** — play a short tone (and optionally a sweep) through the codec;
  ask whether it was heard, at what channel.
- **Rumble** — pulse the motor weak then strong; ask whether it was felt.

**Input devices — read, then show what registered:**

- **Buttons / D-pad / sticks / touch** — display a live map of every input
  surface; as the developer presses each control, light up the one that
  registered, so a mis-mapped or dead control is obvious at a glance.
- **(Later) rebinding** — let the developer reassign which physical control
  drives which logical event, persisting the choice (needs the filesystem,
  phase 4).

### Why this is a utility, not probes

Probes are automated and machine-verifiable — good for "does this register
read the expected value." Output-device validation is the opposite: the
*only* verdict is a human's ("yes I saw the red screen"). Folding that into
the fire-and-log probe battery would be a category error. So this is a
separate, interactive tool — a **chip** (issue 116) — that shares nothing
with the probe engine except the underlying device drivers: probes are data,
chips are code, and they meet only at the drivers beneath both.

### It grows as subsystems land

Each device's validation can only be built once that device's driver
exists, so the utility is incremental:

- rumble and audio-register-read are reachable now (PWM3 + i2c0 are up),
- display validation waits on the framebuffer (111a–111d),
- input validation waits on the input drivers (phase 5),
- audio *playback* waits on the I2S bring-up,
- rebinding waits on the filesystem (phase 4).

A first cut can validate whatever is up (rumble, once its PWM block is
brought up) and add each device as its driver lands.

## Suggested implementation steps

1. Write this issue (done) before code.
2. A small interactive shell: a menu of device tests, driven from the
   input surface once it exists, or from the USB console before then. The
   menu primitive, the console read, and the chip registry this hangs on
   come from issue 116 — this chip supplies the device tests, not the shell.
   Each test drives one device and records a pass/fail verdict.
3. **Rumble test** — bring up the PWM3 block (clock/reset/mux, mirroring
   `led_pwm_init`), pulse `0xFE700020` weak then strong, confirm by feel.
4. **Display test** — once 111d provides a framebuffer, paint the test
   pattern and ramp the backlight; confirm by sight.
5. **Audio test** — once the I2S path and the RK817 codec are configured,
   emit a tone; confirm by ear.
6. **Input test** — once the phase-5 input drivers exist, show the live
   input map; confirm each control by pressing it.
7. Echo every verdict to the SD-backed log (and the USB console when up),
   so a validation run leaves a record even though the verdicts are human.

## Related documents and tools

- `issues/116-chip-scripts-and-console-io.md` — the chip category, console
  read path, and menu primitive this is the first consumer of. Read first.
- `src/020-chips.c` — where this chip is registered and implemented.
- `src/003-pwm.c` (`led_pwm_init`) — the PWM-block bring-up pattern the
  rumble test reuses on the PWM3 block.
- `src/019-probe-engine.c` — the probe engine; its `audio-codec`,
  `display-presence`, and i2c probes gathered the recon above. The probes
  are the machine-verifiable half; this utility is the human half.
- `issues/110n-callable-run-probes-and-runflags.md` — the probe framework
  this deliberately sits beside rather than inside.
- `docs/023-display-controller.md`, issues `111a`–`111d`/`112` — the
  display path the screen test needs.
- Input driver issues `501`–`508` (phase 5) — the input reads the input
  test and rebinding need.
- The board device tree (`libs/sd-image-parts/rk3568-anbernic-rg-ds.dtb`,
  decompile with `dtc -I dtb -O dts`) — source of the joypad/rumble/ADC
  mapping.

## Blocked by

Nothing to *start* (the rumble test is reachable now — PWM3 and the device
tree are known). Each further device test is gated on its driver: display
(111a–111d), input (phase 5), audio playback (I2S bring-up), rebinding
(phase 4 filesystem).
