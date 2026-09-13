# 802 — Two screens, two lenses

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 603, 801 |
| Blocks | 803, 804 |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | G3 |

## Current behavior

Nothing draws on the handheld. The lens record (issue 603) — a layer, an anchor,
a zoom, a place on screen — is designed for a computer window that holds a
list of them. The handheld's compositor, in the sibling project, gives each
screen its own foreground program and hands a program **surfaces** it asks for.
`tests/026-the-handheld.lua` does not reach this issue; the lens tests in
`tests/024-watching-it-happen.lua` are the ones that hold here.

## Intended behavior

The game asks the compositor for two surfaces, one filling each screen, and
splits its lenses across them. The working ruling (G3):

- **Top screen:** a wide lens on the field, switchable to the cloud window.
- **Bottom screen:** a close lens on the field — the one the stylus draws in —
  with the roster and the territory percentage along its edge.

Each screen is drawn by a **box** that takes the snapshot and the screen's lens
and writes pixels into that surface, and nothing else. It is the viewer from
phase 6 with the window replaced by a surface: the lens arithmetic — push,
field-to-screen, screen-to-field — is the same code ported to C, because the
computer's tests already pin what it must do and a lens that behaved
differently on the two targets would make a stylus miss.

The snapshot the boxes read is the one the map's last station produces, copied
out on the wire into the two drawing stations — generate, then view, across a
wire the engine runs for us.

The compositor's damage tracking means a lens that did not move and a snapshot
that did not change cost nothing to leave alone; the drawing box compares the
snapshot's tick to the last one it drew and returns without touching the
surface when they match.

## Suggested implementation steps

1. Port the lens record and its three functions from issue 603 to a box source
   with no memory: the lens is a value on a wire, and a push returns a new lens.
2. Write two drawing boxes, `draw-top` and `draw-bottom`, each taking the
   snapshot, a lens, and a surface handle, writing pixels, and returning the
   tick it drew.
3. Ask the compositor for the two surfaces at map load, one per screen, full
   size.
4. Wire the snapshot station's output into both drawing stations in
   `the-tick.map`, and each screen's lens station into its drawer.
5. Add the cloud-window switch on the top screen as a lens whose layer is the
   cloud, chosen by an input from issue 803.
6. Draw the roster and territory on the bottom surface's edge, from the same
   snapshot.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md)
- [The views](../docs/010-the-views.md) — lenses, and the layers a lens shows
- `tests/024-watching-it-happen.lua` — the lens properties both targets keep

## Still open

- **G3.** Which screen shows what. Top wide and bottom close-and-touched is a
  working ruling; the answer belongs to a person holding the device.
- Whether the top screen's cloud window replaces the wide lens or sits in its
  corner as it does on a computer. The screen is small; replacing is the
  working guess.
