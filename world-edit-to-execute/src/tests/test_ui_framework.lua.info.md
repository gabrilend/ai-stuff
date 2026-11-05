# test_ui_framework.lua

Checks the interface's pieces for issues 506b, 506c, 506e and 506f. It is
headless: a recorder stands in for the renderer.

- **Anchors:** every way of placing a frame, its scaling, its rounding,
  and every refusal. Also that the cache works a size out only once.
- **The console:** at 4:3, 16:9, 21:9, 5:4 and 4K, every part is on
  screen and the console's parts are apart. At 4:3 the layout scales; on
  a wide window the parts keep their 4:3 places while the bars stretch.
  Every key `layout.compute` gives is present. The hud draws, and
  presses a button, with the anchored console in place of layout.lua's.
- **Hit testing:** draw order, hidden and passthrough elements, edges,
  hover, press, click and drag-off, a world drag over the interface,
  disabled buttons, hotkeys, and the chat line's focus.
- **The command card as elements:** a click and the hotkey reach the same
  button.
- **Tooltips:** TRIGSTR_ lookups, hotkey marks, costs and cooldown,
  colours drawn and never shown as codes, wrapping, placement at the
  screen's edges, cutting, and the delay.

**Usage:** `luajit src/tests/test_ui_framework.lua [DIR]`. It exits 1 on a
failure.
