# Button bit order

Every button-shaped input on the device is one bit of the 32-bit
snapshot that `read_buttons` answers once a frame (issue 502). The order
is `enum button` in `src/system/096-input.h`; this note is why it is
that order, and what it is for someone reading a raw snapshot off the
developer line or a memory dump.

| bit | name          | button                          |
|----:|---------------|---------------------------------|
|   0 | `dpad-up`     | D-pad up                        |
|   1 | `dpad-down`   | D-pad down                      |
|   2 | `dpad-left`   | D-pad left                      |
|   3 | `dpad-right`  | D-pad right                     |
|   4 | `abxy-a`      | A                               |
|   5 | `abxy-b`      | B                               |
|   6 | `abxy-x`      | X                               |
|   7 | `abxy-y`      | Y                               |
|   8 | `l1`          | left upper trigger              |
|   9 | `r1`          | right upper trigger             |
|  10 | `l2`          | left lower trigger              |
|  11 | `r2`          | right lower trigger             |
|  12 | `start1`      | center row, first from the left |
|  13 | `select1`     | center row, second              |
|  14 | `select2`     | center row, third               |
|  15 | `start2`      | center row, fourth              |
|  16 | `stick-left`  | left stick, clicked             |
|  17 | `stick-right` | right stick, clicked            |

Bits 18 to 31 are not buttons. `button_track` masks them off, so a pin
read wrongly into one of them is never an event; `BUTTON_ALL` is
`0x3ffff` (262143, which is how the input-poll map writes "every
button").

## Why this order

- **Groups, low to high, in the order the input model names them**
  (`docs/004-input-model.md`): D-pad, face buttons, triggers, the center
  row, stick clicks. A hex dump reads in nibbles: the low nibble is the
  D-pad, the next is ABXY, the next the triggers, the next the center
  row.
- **The D-pad's four directions are bits 0–3** so its eight-way
  direction (two adjacent bits at once) is the low nibble alone, which
  the radial-menu chord (506) reads.
- **The center row is left to right as the buttons sit on the device**
  (`[start1][select1][select2][start2]`), not grouped by name, because
  the drawer each opens follows its position (docs/004, "The four center
  buttons open drawers").
- **The order is not the pins' order.** Which GPIO bank and pin each
  button is on is issue 101's finding; `src/device/098-input-device.c`
  moves each pin to its bit here once that is known, and inverts the
  pins that read low when pressed. Keeping the snapshot's order fixed
  means nothing above `read_buttons` changes when the pins are found.

This is a choice Ritz can overturn; changing it is the enum, this table,
the names in `096-input.c`, and the listen masks written as numbers in
maps.
