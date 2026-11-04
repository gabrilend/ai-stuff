<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, as the datapath for the light flow; updated whenever an issue changes it. -->
# Datapath: light

From a picture to light on the panel.

```
picture (grid of brightness values, numbers 0–1)
  → mask planner: chooses each tab's swing angle and each slot open/closed
      tab state = { angle: number (degrees into the pipe),
                    slots: list of booleans (one per slot along the tab) }
  → tabs move (motion takes time; the old mask holds until they arrive)
  → emitters fire down the light pipe
  → at each point, light passes if every overlapping tab's slot is open
      → passing light: on toward the aperture
      → blocked light: turned aside into the store, circulates, becomes heat
  → aperture opens as the store rotates: one release
      release = { time: number (seconds), energy: number (joules),
                  mask: grid of booleans }
  → light leaves the crown outward
  → the panel, placed by its arm, catches it: the wearer sees the picture
```

Brightness beyond on/off comes from time: a cell open in more releases per
second looks brighter.
