<!-- made by scripts/build-info-pages from the comments in 029-the-front-desk.lua; change the comments and rebuild, not this page -->
# 029-the-front-desk


Joins the game engine to the match. It holds which seat the person is in
(the command table, the commander's seat, the front rank, or the result),
turns keys and clicks into actions through the bindings table of the
configuration, runs the simulation in fixed ticks however fast frames
come, delivers scripted input to the very same handlers a person's input
reaches, and writes the receipt as the last thing the program does.

Seats, actions and script events are all tables of functions; the engine's
callbacks in main.lua call straight into this file.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.seat` | nothing | Which seat the person is in, from the match's act. |
| `M.screenshot` | `name` | (no comment in the source) |
| `M.keypressed` | `key` | (no comment in the source) |
| `M.keyreleased` | `key` | (no comment in the source) |
| `M.mousepressed` | `x, y, button` | (no comment in the source) |
| `M.mousereleased` | `x, y, button` | Releasing the right button lowers the guard and the shields, whichever seat it was raised from. |
| `M.mousemoved` | `x, y, dx, dy` | In the front rank the mouse moves the sword along its U, or, with the look key held, the eyes. |
| `M.wheelmoved` | `dx, dy` | (no comment in the source) |
| `M.load` | `dir, argv` | (no comment in the source) |
| `M.update` | `dt` | (no comment in the source) |
| `M.draw` | nothing | (no comment in the source) |
| `M.finish` | nothing | The last thing the program does: the receipt, then the engine is told to stop. Called once, from a quit or from the window closing. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `ACTIONS` | The actions a key can be bound to. `pressed` is true on press. |
| `BUTTON_ACTIONS` | The actions a mouse button can be bound to, by seat. |
| `SCRIPT` | Script events, delivered to the same handlers a person's input reaches. |
| `DRAW` | What each seat draws. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `new_scenery` | nothing | A new battle gets its own ground, built from its own scenery stream. |
| `held_action` | `action, arg` | Whether any held key is bound to this action and argument. |
| `begin_round` | nothing | (no comment in the source) |
| `intent` | nothing | The player's intent for one tick, from what is held and what is pending. |
| `index_bindings` | `config` | (no comment in the source) |
| `one_tick` | nothing | (no comment in the source) |
| `slide_camera` | `dt` | In the commander's seat the movement keys slide the camera. |
