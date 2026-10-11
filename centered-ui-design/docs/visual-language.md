<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10,
     from the "glass and metal" description in notes/vision. The palette
     values live in code (the palette tokens issue); this file names the
     roles and the rules, not the numbers. -->

# Visual language: glass and metal

## Materials

Everything on screen is one of three materials.

| Material | Used for | How it is drawn |
|---|---|---|
| **metal** | the wheel's body, the rim, dial bodies, bezels, the surface readouts are printed on | a base tone plus a brushed streak texture running *around* the circle (circular brushing, like a watch dial), and a soft highlight that moves as the part rotates |
| **glass** | lenses over readouts, complication windows, the map's glass dome edge | a tinted, slightly darker copy of what is behind it, shifted outward a few pixels toward the edge (refraction), with a bright thin edge line and one curved specular highlight |
| **paint** | buttons only | flat, saturated, bright color with a pressed-in state; the only saturated color on the console |

Both metal and glass come in a **range from dark to bright**: gunmetal,
graphite, steel, silver, polished chrome; smoked glass, grey glass, clear
glass, frosted bright glass. Inner, lower, older parts are darker; outer,
upper, newer parts are brighter. A complication's lower disc is darker than
the face it is seen through.

## Shapes

- Most elements are **circles** or **semi-circles**: the wheel, its rings,
  buttons, dials, readout lenses, complication windows (an arc-shaped slot).
- Text on the rim and in complications follows the arc it sits in.
- Straight edges appear only on the map (terrain) and in the rare debug
  overlay.

## Motion

- **Lots of rotating displays.** The rim turns with weight: it has inertia,
  coasts and settles into a detent at each sector. Readout discs roll to new
  numbers like an odometer rather than jumping. Complication discs turn behind
  their windows.
- Nothing teleports. Everything that changes value rotates or slides there.

## The rule of buttons and numbers

- Pressable means painted. A button is bright and colorful.
- A number is never painted. It is bare metal surface with a glass lens over
  it, so it can never be mistaken for a button.
- This rule is absolute: if something is not pressable, it must not wear
  paint; if it is pressable, it must.

## Map

The map is drawn in muted tones so the console reads first. Tier boundaries
are thin glass rings. Quadrant boundaries are faint radial lines. Couriers are
small bright sparks of the sending stand-in's color running along their route.

## Team colors

Each stand-in has one paint color (used on their buttons, their couriers, the
edge of their quadrant). Foes have darker, desaturated versions of their own
colors so friend and foe never share a hue.
