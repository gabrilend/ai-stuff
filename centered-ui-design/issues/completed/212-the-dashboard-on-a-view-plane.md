# 212 — The dashboard on a view plane

**Phase:** 2 — Glass and metal
**Blocked by:** 209
**Related documents:** docs/console-layout.md, docs/visual-language.md (The
far camera), docs/datapath-glass-and-metal.md
**Completed:** 2026-10-10

## Current Behavior

Built. The dashboard is drawn into three window-sized pictures — face
(brushed metal with windows cut out, painted buttons, engraved labels),
dials (paper discs inscribed with words and numbers, each clipped to its own
window and turned by the game), and glass (how each window bends what is
beneath it) — and laid on a sheet hung in the 3D scene 300 world units in
front of the map, sized so it exactly fills the far camera's view at that
distance and zoom. The flat map is drawn evenly spaced and laid on a ground
disc whose mesh follows the sphere fold, so its rings come out folded.
Checked by screenshot with scripted clicks: the calendar (OCTOBER, SATURDAY,
10 — then SUNDAY, 11 as days pass), framerate, frame time and unit count
dials; buttons dimmed until a unit is named; the named unit's seat and level;
the settings menu.

## Intended Behavior

- The dashboard is a texture laid on a plane in the 3D scene, between the
  camera and the world, at a chosen distance, sized to exactly fill the view
  at that distance and zoom: one texture pixel per screen pixel.
- The flat map texture is laid on a ground disc that follows the sphere
  projection.
- Glass windows bend the paper dial beneath them: a small outward shift
  growing toward the rim, a cool tint, a curved highlight. (First planned as
  bending the world; the design says the dial lies under the glass, so the
  glass bends the dial.)
- Mock-up content: metal face, painted order buttons, calendar dials (month,
  weekday, the day number one level lower), framerate, frame time, unit
  count, the named unit.

## Implementation Steps (as built)

1. `src/003-the-far-camera.lua` (`view_plane_corners`): half-height =
   zoom × (1 − plane distance ÷ camera distance), half-width = half-height ×
   aspect.
2. `src/014-the-dashboard.lua`: the three layers; windows, dials clipped by
   stencil to their windows, buttons, settings panel.
3. `src/015-the-view-plane.lua`: the sheet mesh and its shader (metal over
   glass over dial).
4. `src/012-made-by-formula.lua` (`flat_map`) and `src/013-the-world-renderer.lua`
   (ground mesh of (tier, angle) vertices folded in the shader).
5. Tests: the sheet's corners land on the screen's corners within a hundredth
   of a pixel at three camera distances and zooms.

## Decisions

- Canvas rows: drawing through our own projection into a LÖVE canvas needs
  its y flipped (`FLIP_Y = -1` in 016), confirmed by screenshot (north up,
  text upright).
- Planned as waiting on the rolling readouts and the bright buttons (issues
  205 and 206). The mock-up draws its own simple readouts and buttons instead;
  those issues will replace them, so they no longer block this one.
