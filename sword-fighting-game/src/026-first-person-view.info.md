<!-- made by scripts/build-info-pages from the comments in 026-first-person-view.lua; change the comments and rebuild, not this page -->
# 026-first-person-view


Standing in the front rank. The camera is the player soldier's eyes, with
the vision's 90 degree field of view, and there is no interface at all:
the player sees their own arms and sword, the field, and the bodies.

What the player needs to know is in the picture instead:
  fatigue   the view sways and the edges darken
  a wound   red pulses in from the edges
  the sides soldiers inside the 160 degree awareness arc (narrowed by
            armor) but outside the 90 degree view glow at the screen edge
            on their side: warm for allies, cold for enemies, brighter
            when nearer
  the lock  the locked enemy is drawn a little brighter

The helpers that draw the world (sky, scenery, every figure, darts and
sparks) live here too, and the third-person view uses them.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.sky` | `config, w, h` | (no comment in the source) |
| `M.figure_opts` | `config` | (no comment in the source) |
| `M.add_effects` | `fx, battle` | Sparks for hits, a pale flash for parries: read from the tick's events into the view's own short-lived list, which never touches the battle. |
| `M.age_effects` | `fx, dt` | (no comment in the source) |
| `M.world_parts` | `battle, view, skip, opts` | Every figure, the darts in flight and the sparks, as one part list. `skip` is a soldier not to draw (the player, whose eyes the camera is). |
| `M.camera` | `battle, s, w, h, time` | (no comment in the source) |
| `M.draw` | `battle, view, w, h` | view: the front desk's view state (renderer, scenery parts, fx, time). |

## Tables of rows

| Name | What it is |
| --- | --- |
| `WARM` | (no comment in the source) |
| `COLD` | (no comment in the source) |
| `SPARK` | (no comment in the source) |
| `PARRY` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `gradient` | `x, y, w, h, color, a0, a1, horizontal` | A rectangle fading from one alpha to another, across or down. |
| `awareness` | `battle, s, yaw` | How strongly allies and enemies are felt beyond each edge of the view. |
| `edges` | `battle, s, w, h, yaw` | The only things drawn over the world: light at the edges. |
