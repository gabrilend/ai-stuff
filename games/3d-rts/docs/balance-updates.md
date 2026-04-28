# Balance & Feel Updates

Append-only log of small numeric or sign tweaks to gameplay and input.
Each entry is dated and gives the change plus the reasoning. Larger
behavioral changes belong in issue files — this log is for the kind of
"turn the knob" adjustments that do not warrant their own ticket.

## 2026-04-27 — issue 103 camera input feel

- **Middle-mouse drag pan**: settled on a *mixed* mapping after two
  rounds of feel testing:
  - Mouse Y delta → forward axis directly (mouse down → target moves
    forward toward +X / "red" axis at yaw=0).
  - Mouse X delta → right axis *negated* (mouse right → target moves
    along +Y / "green" axis at yaw=0).
  The first attempt fully inverted both axes; the second attempt
  flipped both back; the green axis was wrong in the second pass and
  is now negated alone. Both prior attempts left commented-out trails
  in the source code that have since been deleted.
- **Q / E yaw rotation**: swapped. Q now rotates yaw positive
  (clockwise looking down), E rotates negative. The original pairing
  felt backwards during testing.

Both changes live in `src/030-camera.c` near the input handling and
include short comments pointing back at this entry.
