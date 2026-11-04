# 1003 — A fan with one permission

**Phase:** 10 — The machine answers
**Blocked by:** 1001
**Blocks:** 1004
**Related documents:** delta-version issue 066 (notes on this machine's fan
controller chip, which Linux does not see yet)

## Current Behavior

No fan is driven. The first fan will be an external one on a different
machine, driven over its own signal (for example a USB microcontroller), since
this machine's motherboard fan chip has no driver loaded.

## Intended Behavior

Any fan (which one is arbitrary), behind an output adapter run by a separate
system user whose only permission is the one file or device that sets its speed, reads the signal inbox and sets the speed. It
never goes below what CPU temperature calls for; on any error it hands the
fan back to automatic mode and stops, loudly.

## Suggested Implementation Steps

1. External-fan adapter over USB serial; motherboard-header adapter later.
2. Create the user; a udev rule grants it that one file at boot.
3. Value-to-speed mapping, temperature floor, hand-back on error.
