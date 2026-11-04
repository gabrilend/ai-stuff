# Issue 066: Fans That Follow a Signal

**Status**: Open — nothing built; first fan will be an external one
**Priority**: Low
**Created**: 2026-10-10
**Type**: New tool; proof of concept for turning any signal into a physical motion
**Related**: `centered-ui-design` issues 1001–1004 (a parallel build of this
same system); `/mnt/mtwo/programs/r-mail/docs/attachments.md` (the chunked
delivery style the signal borrows)

---

## Why this exists

> can we make a script or utility that spins the fans faster or slower
> depending on... some un-described input signal? We define how it must be
> delivered, then we spin the fans accordingly. That input signal should be...
> the pitch register of a transcription of short, sentiment sentences would be
> described. as a proof of concept, but we can attach it to any such signal.

The fan is the first output. The point is the delivery contract: anything that
can speak it can move the machine.

## Current Behavior

Nothing drives the fans. On this machine (Gigabyte X299 AORUS Gaming 3) Linux
sees only two hardware monitors — the NVMe drive and the CPU's temperature
sensors. The motherboard's fan-controller chip has no driver loaded, so no fan
speed file exists to write to. Gigabyte boards of this era use an ITE
"Super I/O" chip (most likely the IT8686E); the kernel's `it87` driver may need
loading, possibly with a forced chip id, or the out-of-tree `it87` driver that
supports newer ITE chips. This has not been tried, and will not be: she will
set up a different machine for this, with an external fan driven over some
other signal (for example a small USB microcontroller producing the fan's
speed pulses).

## Intended Behavior

Three parts, kept apart.

### 1. The signal (delivery contract)

A signal is a series of values from 0.0 to 1.0 (floating-point number), each
with a time (seconds since the signal began, number). **The signal carries its
own mapping**: a low and a high end (each a fraction of full speed, number),
so 0.0–1.0 may mean the span between two ten-percents or the whole range —
"it just depends on how the hardware is designed to rely best through." It arrives in one of two
ways, as she put it — "either a stream, or a single input setting":

- **single setting**: one value, held until replaced;
- **stream**, sent in rmail-attachment style: "it's been N seconds since the
  last sent message, so I send M bits of data from the next end of the
  section." The sender keeps a queue; each send carries the next chunk of
  values, numbered, so chunks can arrive late or out of order and be put back
  in sequence, and a missing chunk is asked for again.

Values are written as files into an inbox folder in `tmp/shared-memory/`, one
file per chunk, named by sequence number. The fan side never asks where a
signal came from.

### 2. The source (proof of concept)

Short sentiment sentences are spoken or transcribed; the pitch of each
sentence's voice (its register — low, middle, high) becomes one value per
sentence, or a stream of values across the sentence. Any other source that
writes the same chunk files works the same.

### 3. The fan side

Any fan — which one is arbitrary. The fan side is an output adapter: one for
a motherboard fan header, one for an external fan on its own controller; each
runs as a separate system user whose only permission is the one file or device
that sets its speed. It reads the inbox,
maps each value to a speed, and writes it. Safety floor: never below the speed
the CPU temperature calls for; on any error, hand the fan back to automatic
mode and stop, loudly.

## Suggested Implementation Steps

1. External fan adapter first: a microcontroller over USB serial that turns a
   number into the fan's speed pulses; a motherboard-header adapter later
   (find its monitor by name — hwmon numbers change between boots).
2. Create the fan user; give it write access to that one device or file only
   (a udev rule that sets its group at boot).
3. Write the delivery contract and its reader (Lua): single setting and
   chunked stream, reordering, re-asking for missing chunks.
4. Fan writer with the temperature floor and the hand-back-to-automatic on
   error.
5. Pitch source: transcribe, measure pitch per sentence, write chunks.
6. Tests: a recorded stream with chunks out of order and one missing.

## Answered Questions

- Which fans: arbitrary.
- Mapping: carried by the signal, low and high end chosen to suit the hardware.

## Open Questions

None open.
