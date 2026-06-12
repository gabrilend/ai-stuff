# Bricking risks and recovery — Soren DS development safety

This document enumerates every way the Anbernic RG DS could be made
unusable as a result of our development, ranks each scenario by how
likely it is to happen and how bad it would be, explains the
mechanism, and prescribes a design rule that prevents it.

A constraint from the project that frames everything: **the device
cannot be opened.** Any recovery procedure that requires physical
access to the inside of the case is not available to us. This
makes the question "can we trigger the chip's ROM-level recovery
mode without opening the case?" the single most important
unknown in this entire phase, because it determines whether we
have a safety net beneath every other risk in this document.

## What "brick" means here

A device is **bricked** when it has no path back to a working state
through normal user-accessible means. We distinguish three levels
of severity, and our design must keep us in the first two at worst.

- **Soft brick.** The device is in a bad state but still responds
  to a recovery procedure. A reflash using the standard
  development tools fixes it. Annoying but not catastrophic.
- **Hard brick.** The standard procedure no longer works, but a
  lower-level recovery (Maskrom) does. Reflashing through Maskrom
  fixes it. Requires us to know how to reach Maskrom.
- **Permanent brick.** Even Maskrom is gone, or the silicon itself
  is damaged. Repair is hardware-level. The device is dead.

## The boot and firmware layers, lowest to highest

Damage at each layer has a different recovery path. Understanding
where in this stack a brick happened is the foundation of
designing safe code.

### Layer 0 — Chip ROM (Maskrom)

A small bootloader burned into the RK3568's silicon at the
factory. Cannot be erased, cannot be rewritten, cannot be
disabled by software (with one exception we cover under secure
boot below). When the chip is reset:

- It checks whether the next layer (the loader on eMMC) is intact
  by reading a magic number.
- If yes, it hands control to the loader.
- If no, OR if a GPIO held during reset forces it, it enters
  Maskrom mode and waits on USB for a host to upload code.

Because this ROM lives in silicon, **Maskrom is the unbrickable
safety net — as long as we can trigger it from outside the case.**
Whether we can do that on the RG DS is the open question this
document keeps returning to.

### Layer 1 — Loader (RKDDRBin + miniloader)

Lives in a fixed area of eMMC. Initializes the chip's DDR memory
controller and loads u-boot. If corrupted, layer 0 falls back to
Maskrom.

### Layer 2 — u-boot

Reads the partition table, picks a kernel image, loads it into RAM,
and jumps to it. Also supports its own USB-based flashing modes
(fastboot, DFU) and its own command shell if a console is reachable.

### Layer 3 — Boot partition

Kernel image plus initial ramdisk. This is where our Soren DS
kernel will live. If corrupted, u-boot can fall back to a recovery
partition if one exists.

### Layer 4 — Recovery partition

An alternate kernel and ramdisk for emergency recovery. Standard
Android devices ship one. If our setup preserves it, we get a
free fallback path.

### Layer 5 — System partition

Android system files on stock firmware. We replace this entirely.

### Layer 6 — Userdata

Apps and user settings. Not relevant to bricking.

### Layer 7 — Partition table, misc, eFuses

Metadata about partitions and boot flags. eFuses are one-time
programmable silicon registers — touching the wrong one is
permanent. We treat this layer as off-limits.

---

## Bricking scenarios, ranked

For each: the cause, the mechanism (why it happens), the recovery
path, the severity, and the design rule that prevents it.

### S1 — Power loss during flash

**Likelihood:** Medium. Will happen at least once in a project
this long.

**Cause:** Battery dies or USB cable disconnects while a kernel
image is being written to eMMC. The boot partition is half-old,
half-new — corrupt.

**Mechanism:** eMMC writes are atomic at the small-block level
but not at the partition level. Writing a 4 MB kernel image takes
hundreds of milliseconds, and an interruption mid-way leaves
partial data with no way for u-boot to know.

**Recovery:** Boot from the recovery partition and re-flash. OR
enter Maskrom and re-flash. Both work.

**Severity:** Soft brick. Recoverable.

**Design rule:** A/B partition scheme. Two boot slots, A and B.
We write to the inactive slot, verify the write checksum, then
flip the active-slot flag — which is itself a single atomic write
to the misc partition. If power dies mid-write, the previously
active slot still works because it was never touched.

### S2 — Bad kernel image, doesn't boot

**Likelihood:** Very high. This will happen routinely during
development, because writing a kernel that doesn't boot the first
time is the default outcome of writing a kernel.

**Cause:** A bug in our kernel causes it to crash before the
device is usable, or it hangs in an infinite loop.

**Mechanism:** The kernel runs for some duration after u-boot
hands off, then hits a fault — a bad pointer, a divide-by-zero,
an unhandled exception — or it enters a loop with no exit. The
screen stays dark, the LEDs may or may not blink, the device
sits there.

**Recovery:** Watchdog reboot. A/B slot revert. Re-flash via
Maskrom.

**Severity:** Soft brick.

**Design rule:** Watchdog always on. Configure the hardware
watchdog as soon as the kernel can. Pet it every iteration of
the main scheduler loop. A boot-success flag is written by our
kernel only after the system is verifiably usable — at minimum,
the LEDs are responding and the USB debug stream is up. If
u-boot sees N reboots without a success flag, it reverts to the
previous slot.

### S3 — Wrong-target image

**Likelihood:** Low if the build script validates targets, high
if it doesn't.

**Cause:** A build accidentally picks up the wrong toolchain or
the wrong linker script and produces an image for a different
chip family. Flashing it bricks the boot partition.

**Mechanism:** u-boot tries to load and execute the image. Either
it fails a magic-number check and refuses to boot, or it tries
to execute and the CPU faults on the first instruction.

**Recovery:** Same as S2.

**Severity:** Soft brick.

**Design rule:** The build system embeds a chip-ID magic number
into the image header at compile time. Our boot code (or u-boot,
if configured) checks the magic before executing. Mismatch means
refuse to boot, do not jump.

### S4 — Driving a GPIO to a dangerous configuration

**Likelihood:** Medium during early driver development.

**Cause:** Our driver code configures a GPIO as an output and
drives it to a level that conflicts with what's wired to the other
end of that pin. For example, driving a power-rail-enable pin to
the wrong state, or shorting an input pin against a fixed level
through a low-impedance output.

**Mechanism:** A GPIO output driver inside the SoC can typically
source or sink a few milliamps. If the pin is wired to something
that fights the SoC's driver — a strong external pull-up against
a SoC driving low, for instance — current flows through the SoC's
internal output transistor. Most modern SoCs have internal current
limits, but pushing them long enough degrades transistors.

**Recovery:** Hard to determine. May still work but be degraded.
May fail intermittently.

**Severity:** Possible long-term chip damage.

**Design rule:** Only configure a GPIO as an output after we have
explicit documentation of what's wired to it. Until 101's
research has confirmed a pin's wiring, we read it but do not
drive it. Inputs are safe; outputs are committed.

### S5 — Misconfiguring the PMIC

**Likelihood:** Low if we follow the rule below.

**Cause:** Our code writes to the power management IC's registers
and sets a voltage rail to a value outside the documented safe
range. For example, telling the rail that powers the RAM to
deliver 1.8V when the RAM is rated for 1.5V.

**Mechanism:** PMICs expose their output voltages as I2C
registers. The PMIC will obey what we tell it. Components
downstream of the rail receive whatever voltage we've configured;
they have no way to refuse a bad voltage. Silicon outside its
operating range fails — sometimes immediately, sometimes after
some time of mistreatment.

**Recovery:** None for damaged silicon. The chip is permanently
degraded or destroyed.

**Severity:** Permanent damage if it happens.

**Design rule:** Never write to PMIC voltage-setting registers.
Use only the documented read commands (battery percentage, USB
power presence, temperature) and the documented sleep/shutdown
control commands. Voltage configuration was set at the factory
to match the components on this board and should never change
under our software.

### S6 — Thermal abuse

**Likelihood:** Low. Modern silicon is well protected.

**Cause:** Our kernel keeps the CPU at maximum clock without
sleeping or throttling, and we don't read the thermal sensor.
The chip overheats.

**Mechanism:** The RK3568 includes a hardware thermal sensor that
triggers an emergency shutdown above a critical temperature
(typically around 110°C). Immediate hard brick is unlikely
because the silicon protects itself. But sustained operation just
below the shutdown threshold accelerates silicon degradation over
time — transistors wear out faster, the chip becomes less
reliable.

**Recovery:** None for accumulated wear. Immediate damage is
prevented by the silicon's own protection.

**Severity:** Long-term degradation.

**Design rule:** Sample the thermal sensor periodically. Throttle
the CPU clock or sleep idle cores when temperature exceeds a
documented safe operating threshold. Never disable the chip's
built-in thermal protection.

### S7 — Battery deep discharge

**Likelihood:** High during development if not designed against,
because a kernel that doesn't sleep will burn the battery.

**Cause:** Our kernel runs a tight loop that never sleeps and
never monitors battery level. The battery drains below the safe
discharge threshold (typically 2.5V per lithium cell).

**Mechanism:** Lithium-ion cells discharged below the safe
threshold develop internal short circuits as the copper anode
begins to dissolve into the electrolyte. The PMIC may refuse to
recharge a cell discharged this deeply, as a safety feature.

**Recovery:** Replace the battery. On a sealed device this
requires opening the case, which we have already said we can't
do.

**Severity:** Functionally hard brick if the user cannot open the
device — the cell is dead and not coming back.

**Design rule:** Monitor battery voltage every few seconds.
Request a PMIC sleep (which preserves battery state) at a defined
safe threshold, typically 3.4V per cell — well above the danger
zone. Never override the PMIC's built-in discharge cutoff.

### S8 — Display panel damage

**Likelihood:** Very low if we use documented modes.

**Cause:** Driving the display controller at frequencies or
voltages outside the panel's documented range, or setting the
backlight LED current above its rated value.

**Mechanism:** LCD panels are tolerant of many input variations
but can be damaged by sustained out-of-spec timing. Backlight
LEDs burn out if driven above their rated forward current for
sustained periods.

**Recovery:** Replace the panel, which requires opening the case.

**Severity:** Functional component damage.

**Design rule:** Use only display modes documented in the
panel's datasheet (which 101 must retrieve). Don't experiment
with backlight PWM values outside the documented range.

### S9 — eFuse / OTP writes

**Likelihood:** Very low unless we explicitly invoke a fuse-write
command, which we never should.

**Cause:** Our kernel or our build process accidentally invokes a
command that writes to the chip's one-time-programmable
security memory.

**Mechanism:** eFuses are physical fuses inside the silicon.
Writing them blows the fuse. They cannot be reset. The chip's
behavior is permanently changed — typically to lock the bootloader
to a specific signing key or to require secure boot.

**Recovery:** None. The chip is changed forever. Replace device.

**Severity:** Permanent brick.

**Design rule:** Our kernel never contains code that writes to
the eFuse controller address range. Our flashing scripts never
invoke any `rkdeveloptool` subcommand that writes fuses (commands
prefixed `wf`, `wsf`, or similar). This is enforced by code
review and by a deny-list in the build system.

### S10 — Accidental secure-boot enable

**Likelihood:** Very low if S9's rule is followed.

**Cause:** We accidentally enable the secure-boot eFuse without
having an authorized signing key on the chip.

**Mechanism:** Secure boot is one of the eFuses described above.
Once enabled, the chip's bootloader only executes images signed
by a specific key. If we don't have that key set up, every
subsequent flash is rejected.

**Recovery:** None. Same as S9.

**Severity:** Permanent brick.

**Design rule:** Same as S9. Secure boot is an eFuse; we don't
touch eFuses.

### S11 — Watchdog absence plus kernel hang

**Likelihood:** Very high during development.

**Cause:** The kernel enters a state where nothing happens (an
infinite loop, a deadlock between threads, a panic that doesn't
trigger reboot). The device appears dead.

**Mechanism:** Without a watchdog, nothing tells the chip to
reset. The kernel sits at zero throughput while the battery
drains in the background (compounding into scenario S7).

**Recovery:** Force a hardware power-off, usually by holding the
power button for many seconds — the PMIC treats this as an
emergency-off signal, even when software is unresponsive.

**Severity:** Soft brick at most, usually just an annoyance.

**Design rule:** Configure the hardware watchdog as soon as the
kernel is able to. The scheduler pets it every iteration. If the
scheduler hangs, the watchdog kicks the device after its timeout.

### S12 — eMMC wear

**Likelihood:** Very low in normal use, but worth noting.

**Cause:** Our kernel writes to flash storage at a high rate (a
log file flushed every millisecond, for instance).

**Mechanism:** eMMC cells have a finite write-endurance count.
Modern eMMC is good for thousands to hundreds of thousands of
write cycles per cell, with wear-leveling distributing writes
across the chip. A pathologically write-heavy kernel can still
wear cells faster than expected.

**Recovery:** None for worn cells. Bad blocks accumulate over
time and the storage becomes less reliable.

**Severity:** Long-term degradation.

**Design rule:** Logs and ephemeral writes go to the RAM-backed
`tmp/` directory (the symlink in the project root points there),
not to eMMC. Persistent writes happen only when the user changes
something they explicitly intend to save.

---

## The Maskrom access question

Every "soft brick" scenario in this document is recoverable
through Maskrom. Maskrom is reachable only by:

1. **A physical button or pad on the PCB** held during power-on.
   On the RG DS specifically, where this button is and whether
   it's accessible from outside the case is not documented in
   any community resource we could find. **This is the open
   question.**
2. **A software request from a running u-boot.** If we can reach
   a u-boot shell — over USB serial, over UART, or by interpreting
   onscreen u-boot output — we can run a command that triggers
   Maskrom on the next reset.
3. **An ADB / fastboot chain from running Android.** If the stock
   OS is reachable and ADB is enabled, `adb reboot bootloader`
   may put the device in fastboot mode, and from there
   `fastboot reboot-bootloader` may chain into Maskrom on some
   Rockchip implementations.

If none of those three paths works from outside the case on the
RG DS, **we cannot recover from a hard brick.** Every flash
becomes a one-way operation. The design rules above must be
followed strictly. There is no safety net beneath them.

**Before any low-level flashing experimentation, we must confirm
at least one of those three paths works.** This is the highest
priority research item — higher than the chip details we already
have, higher than the display registers, higher than any other
hardware research.

The most likely path to confirm without opening the case is path
3 (ADB chain through running Android). This requires running the
stock OS once with the device connected to the laptop — exactly
the thing we wanted to avoid for malware reasons. The malware
concern and the safety-net concern are in direct conflict. A
practical compromise: run the stock OS with the laptop's USB
permissions restricted to ADB only (no mass storage mount), and
confirm the ADB-to-fastboot-to-Maskrom path works once. After
that, we have a safety net and the stock OS doesn't need to be
plugged in again.

---

## What to never do

1. Never invoke any `rkdeveloptool` command that writes fuses
   (commands beginning with `wf`, `wsf`, or any documented as
   modifying secure memory).
2. Never write to the chip's eFuse controller address range from
   kernel code.
3. Never write to PMIC voltage-setting registers from kernel code.
4. Never disable the hardware watchdog after it's been configured.
5. Never disable the chip's built-in thermal protection.
6. Never override the PMIC's battery low-voltage cutoff.
7. Never drive a GPIO as an output until its wiring is documented.
8. Never use display timings outside the panel's datasheet
   specification.
9. Never overwrite the partition holding u-boot during normal
   kernel updates. Update only the boot partition.
10. Never flash without first confirming the build image's
    chip-ID magic matches the target.

## What to be extra careful about

1. **The boot-success flag** for the A/B slot scheme. Write it
   only after the kernel is verifiably usable — the LEDs respond,
   the USB debug stream is open, the framebuffer is producing
   pixels. Writing it earlier defeats the whole revert-on-failure
   mechanism.
2. **The PMIC sleep command.** Triggering sleep without a wake
   source means the device never wakes. Always configure at least
   one wake source (a button press, a USB connection event)
   before requesting sleep.
3. **The first-ever flash of a new feature.** This is the
   operation we have the least practice with and the lowest
   confidence in. Do it with the device fully charged, with the
   USB cable held in firmly (not just plugged), with no other
   heavy load on the laptop that might disconnect USB.

---

## Summary recommendation

The single most important action before phase 1's flashing work
begins: **confirm that Maskrom or fastboot is reachable from
outside the device's closed case.** Until that confirmation
exists, every flash is a potential one-way trip. After it exists,
every other risk in this document is manageable through the
design rules above.

If no Maskrom-from-outside path can be confirmed, the project's
risk profile changes substantially: we move to an ultra-conservative
flashing model where we only ever touch the boot partition (never
u-boot, never the loader, never the partition table), we always
keep a known-good boot image we can revert to, and the A/B slot
scheme becomes mandatory rather than optional. This is workable,
but it removes most of the freedom to experiment.
