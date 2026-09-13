# 806 — Two handhelds play a match

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 707, 803, 804, 805 |
| Blocks | — |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | F4 |

## Current behavior

Nothing, and **design pending details on soren-ds wifi capabilities.** This is
phase 8's capstone. Every blocker is open, and the last of them — reaching a
peer from the handheld — cannot be finished until the sibling project has
measured five things its documents do not yet hold:

1. whether the radio chip supports ad-hoc mode at all;
2. the bandwidth, latency and loss rate between two handhelds in a room;
3. the largest datagram the link carries;
4. how many peers one radio can hear;
5. what sustained sending costs in battery.

Nothing has run on a device. `tests/026-the-handheld.lua` asserts the purity
of the Lua systems that issue 801 ports, and nothing more.

## Intended behavior

Two handhelds side by side, with nothing between them but air, find each other
through the system's peer table, lobby on this game's port, open a match on
one seed, and play it to the end with the stylus and the drawers — every
placement, pattern, level and launch taking effect on both at the same tick,
and the hashes holding throughout.

Before that, and worth more as evidence: **one handheld and one computer play
the same seed and print the same hash.** That run answers F2 for real. If the
hashes diverge, the halt names the tick, the two snapshots are diffed, and
positions become fixed-point integers before anything else in this phase is
touched.

The **phase 8 demo** is the pair of runs above, scripted as far as a device
allows: `issues/completed/demos/phase-8-demo` builds the handheld target,
builds the desktop twin, runs the twin and the Lua on one seed and prints their
hashes, and then prints the steps a person follows to flash two devices and
read their goodbye lines off the card's log region. The first half passes
unattended; the second half is a checklist, because two handhelds in a room are
not something a script can arrange.

## Suggested implementation steps

1. Wait for issue 707's five measurements and put them in the catalogue.
2. Build with `./compile --target handheld` and run the desktop twin against
   the Lua for a whole headless match; hold the hash.
3. Flash one device by the sibling project's path, run the same seed with the
   bot behind it, and read its goodbye — final tick and hash — off the log
   region. Compare.
4. Flash the second device. Lobby over the radio, open, and play a match with
   two people. Read both goodbyes.
5. Write the phase 8 demo script as described, and the checklist it prints.
6. Everything that was wrong goes to group H on the open questions page.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md)
- [Other players](../docs/011-other-players.md) — the handheld transport
  section and its five unknowns
- `./run-phase-demo` — the front door to the demo this issue ends with
- `tests/026-the-handheld.lua`

## Still open

- **F4.** The five radio unknowns above, pending the sibling project's radio
  phase.
- What the device's goodbye is written to. On a computer it is `output/goodbye`;
  on a device the nearest thing is the SD card's log region, which the sibling
  project's tooling reads. The demo's checklist assumes that.
