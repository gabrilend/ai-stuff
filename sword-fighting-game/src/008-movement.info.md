<!-- made by scripts/build-info-pages from the comments in 008-movement.lua; change the comments and rebuild, not this page -->
# 008-movement


Turns a soldier's wish to move into a step, and enforces who may stand
where. The rules, from the vision:

  enemy-held cells are walls: nobody can push anyone around;
  ally-held cells may be entered at half speed, and the ally steps the other
    way by itself, along its own dodge movement (not pushed by the mover);
  a dodge never lands in an occupied cell;
  the field's edge is a wall.

The trip rules (007-stamina.lua) are asked here, on the tick a backstep or a
guarded sidestep begins.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.give_yield` | `battle, ally, mover` | The ally has been given the mover's old cell; it steps to that cell's centre by itself, at its own yield speed. |
| `M.step` | `battle, s, dt` | One tick of movement. Lying down, nothing moves; yielding and dodging carry on by themselves; otherwise the soldier walks by its intent. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `count` | `battle, name` | (no comment in the source) |
| `try_move` | `battle, s, nx, ny, allow_ally` | Moves s to (nx, ny) if the cell there allows it. Returns "moved", "blocked" or "ally" (the step leads into an ally's cell and has not been taken, so the caller may retry it at half speed). |
| `apply_motion` | `battle, s, dx, dy, ally_share` | Moves by (dx, dy), sliding along walls: the whole step, else each axis alone. A step into an ally's cell is retried at the ally-pass share. |
| `speed_share` | `battle, s, forward` | Every multiplier on walking speed, in one place. |
| `check_trips` | `battle, s, forward, side` | The trip rules fire when a step begins, not on every tick of it. |
| `start_dodge` | `battle, s, forward, side` | A quick step in the wished direction (backward when there is no wish). It is refused before it starts if its landing cell is held by anyone. |
| `step_yield` | `battle, s, dt` | (no comment in the source) |
| `step_dodge` | `battle, s, dt` | (no comment in the source) |
| `step_walk` | `battle, s, dt` | (no comment in the source) |
