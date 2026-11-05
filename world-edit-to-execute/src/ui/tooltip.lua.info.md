# tooltip.lua

A button's tooltip (issue 506f): its text, colours, costs and a place on
screen.

- **`tooltip.content(b, { resolve })`** returns the title, body and costs:
  - The title is `title` or `label`. It gets the hotkey after it, unless
    the title already marks the hotkey in colour, as WC3's do.
  - The body is `ubertip` or `tip`.
  - The costs line holds gold, lumber, food and mana that aren't zero,
    and `cooldown_seconds`.
  - TRIGSTR_ references are looked up through `resolve(token)`, for
    example the map's `war3map.wts` through `parsers/wts.lua`. A
    reference that isn't found stays as it is.
- **`tooltip.build(ui, b, near, sw, sh, options)`** lays the tooltip out:
  - Lines are wrapped to the box's width in pixels by
    `script_ui.lines`, which keeps `|cAARRGGBB ... |r` colours across a
    wrap and honours `|n`.
  - The box sits above the button, right edges together, or below it
    when there is no room above.
  - It is pushed back onto the screen and is never wider than the screen.
  - When it is too long for the screen, it is cut, ending with `...`.
- **`tooltip.draw(ui, t)`** draws it through `render.ui_*`, with the
  colour codes as colours (`script_ui.text`).
- **`tooltip.place(w, h, near, sw, sh)`**: the placement alone.
- **`tooltip.timer(delay)`**: `:update(button, dt)` turns true once the
  same button has been under the mouse for `delay` seconds
  (`tooltip.DELAY`, 0.25).

This module is not wired into `hud.lua`. The hud's own tooltip (which
strips the colours and stays in a fixed place) remains until the owner
chooses.
