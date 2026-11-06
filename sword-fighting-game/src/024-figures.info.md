<!-- made by scripts/build-info-pages from the comments in 024-figures.lua; change the comments and rebuild, not this page -->
# 024-figures


A clay soldier in brick armor, built from one soldier record and nothing
else. The result is a list of parts the renderer draws: { shape, model,
sx, sy, sz, color, look }.

Every figure is built in its own frame first, in metres: x forward, y up,
z to the right, feet at the origin. The frame is then placed on the field,
turned to the soldier's facing and scaled by its height.

The sword is posed from the record: at rest it sits on the U; during a
swing it travels from the rest pose to the kind's windup pose, then sweeps
to its strike pose as the windup ends, and returns during the recovery.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.rest_pose` | `u` | The grip on the U: the arms of the U rise beside the target, the bend dips in front of it. |
| `M.hand_pose` | `s` | (no comment in the source) |
| `M.build` | `out, s, opts` | opts: cell (metres per cell), clay ({r,g,b}), team_colors, only_arms (first person: the player's own arms and sword), bright (the lock), pennant (mark the player in third person). |

## Tables of rows

| Name | What it is |
| --- | --- |
| `DARK` | (no comment in the source) |
| `WOOD` | (no comment in the source) |
| `GREY` | (no comment in the source) |
| `POSES` | Hand poses: where the grip is and which way the blade points, in the figure's frame. Slashes are written from the left; the right is mirrored. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `part` | `out, base, shape, local_m, sx, sy, sz, color, look` | (no comment in the source) |
| `blob_at` | `out, base, x, y, z, sx, sy, sz, color, look` | (no comment in the source) |
| `shape_at` | `out, base, shape, x, y, z, sx, sy, sz, color, look` | (no comment in the source) |
| `span` | `out, base, shape, a, b, r, color, look` | A shape stretched from one point to another in the figure's frame. |
| `mirror` | `p, side` | (no comment in the source) |
| `lerp_pose` | `a, b, t` | (no comment in the source) |
| `torso` | `s` | The torso's frame: leans forward with fatigue, pivoting at the hips. |
| `at_torso` | `t, x, y, z` | (no comment in the source) |
| `add_sword` | `out, base, s, pose, team_color` | (no comment in the source) |
| `add_armor` | `out, base, t, s, color` | More armor is more bricks: a chest plate always, shoulders from two points, a helmet from three; thick armor makes every plate bigger. |
| `add_shield` | `out, base, t, color` | A round shield on the left arm, its rivets pressed in a cat's face. |
| `base_matrix` | `s, cell` | The figure's frame on the field. Lying down (tripped or fallen) tips it onto its back. |
| `tint` | `c, k, grey` | (no comment in the source) |
