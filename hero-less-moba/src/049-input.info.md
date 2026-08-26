# 049-input

Clicks and keys in; camera motion and command records out. Nothing else.

## What it is for

This file may move the camera, because the camera is not world state — it is where a
person is looking, and nobody else needs to know.

It may **not** touch a chest, a slot, a body, or a structure. Everything it wants the
world to do, it asks for by putting a command in the queue and waiting for the next
tick, exactly as a bot or a replay would. Keeping that line means every bug has a side:
if a frontline moved wrong, this file is innocent, because it cannot move a frontline.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `create()` | | The input state. |
| `keypressed(state, context, key)` | | — |
| `wheel(state, context, dx, dy)` | | — |
| `mousepressed` / `mousereleased` / `mousemoved` | | — |
| `update(state, context, dt)` | | — Held keys, once a frame. |
| `world_drop(world, camera_module, camera, team, kind, x, y)` | | The command a drop here would mean, or nil. |
| `key` | *(table)* | The key dispatch table. |

## The input state

`held_kind` (the upgrade riding the cursor, 0 for none), `watching` (which team's
board), `panning`, `paused`, `speed`, `mouse_x`, `mouse_y`.

## The two gestures that matter

**The wheel zooms to the cursor.** Not to the centre of the screen. A player puts the
cursor on the fight they want to read and turns the wheel.

**An upgrade is placed by dragging it onto the thing it should affect** — a lane in the
world, or a tower in the world — rather than picking it out of one menu and a
destination out of another. The chest and the lanes are the two things a player's eyes
move between constantly, so a placement should be a short drag and not a trip across
the screen.

## The bindings

| Key | Does |
| --- | --- |
| `home`, `space` | Frame the whole map. **Two keys for one action**, because it is the action that must never be hunted for. |
| arrows, `WASD` | Pan. |
| `=`, `-` | Zoom about the centre of the viewport. |
| `tab` | Switch which team's board is shown. Prototype only. |
| `p` | Pause. |
| `1`, `2`, `3` | Speed. |
| `escape` | Quit. |

Left mouse is the chest, because the chest is the thing a player is actually doing and
it should have the button their hand is already on. Right and middle drag the world.

## Where a drop lands

Stone is checked **first**, because a tower sits on a lane and both would otherwise
answer. Then the nearest lane, within a generous reach — a lane is a long thin thing
and a player aiming at one is aiming at a corridor rather than at a point.

Dropping on the library slots into it, which reaches all three base towers. Dropping on
a **base** tower is refused **by name**, because a player who tries it is reaching for a
real rule and deserves to be told which one.

A drop into empty space returns nil rather than a refusal. That is a player changing
their mind, not a player being told no, and filling the refusal log with "you dropped
that on the grass" would train them to ignore it.

## Two details that keep the line clean

**Picking up a chip does not remove it from the chest.** Nothing moves until a command
is applied at the top of a tick; a chip that vanished on pick-up would be the viewer
holding state the simulation needs.

**Only your own structures answer a drop.** Dropping on an enemy tower is a miss, and it
falls through to whatever else is under the cursor rather than producing a message about
ownership.

## Why panning is in `update` and not in `keypressed`

A held arrow key should pan continuously, and a key repeat is not a smooth motion.
