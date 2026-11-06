# hit.lua

Which interface element the mouse is on, before the world gets it (issue
506c). The interface is a list of flat element records: `id`, `x`, `y`,
`w`, `h`, `order` (higher is on top), `visible`, `disabled`,
`passthrough`, `kind` and `hotkey`.

- **`hit.test(elements, x, y)`**: returns the element on top at that
  point (the highest order; at equal order, the later one), or nil when
  the point is the world's. Hidden and passthrough elements are never
  hit. A disabled one is hit, so it still blocks the world.
- **`hit.hotkey(elements, key)`**: returns the visible, enabled element
  with that hotkey, in either case.
- **`hit.tracker()`**: `:update(elements, input)` is called once a frame
  with the hud's input table.
  - It returns events: enter, leave, press, release, click (pressed and
    let go on the same element), hotkey, focus, blur, submit and text.
  - It sets each element's `state` to normal, hovered, pressed or
    disabled.
  - A text entry (`kind = "text_entry"`) takes the keyboard focus when
    clicked. While it has focus, keys are typing (`text` events), not
    hotkeys. Enter submits and Esc drops the focus.
  - `ui_owns_mouse` says whether this frame's mouse belongs to the
    interface: it does while the mouse is over the interface, and during
    a press it belongs to whatever the press began on.
- **`hit.from_layout(r, extra, open_panel)`**: turns `layout.compute`'s (or
  `console_frames.compute`'s) table into elements. The bars and panels
  block the world; the menu, minimap, hero, idle and inventory buttons
  carry their hotkeys. `extra` adds the command card's elements
  (`commands.elements`).

This module is not wired into `hud.lua` or `input.c`. The hud keeps its
own `over_ui` test until the owner chooses (issue 506c).
