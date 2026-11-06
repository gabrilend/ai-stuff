# console_frames.lua

WC3's console as anchored frames (issue 506b), resolved by `ui/anchor.lua`.
It holds the same parts that `layout.lua` (518b) places by pixels.

- The top bar and the console's bar stretch across the whole window.
- Every part on them keeps its place in the 4:3 area: menu buttons,
  clock, resources, minimap and its five buttons, portrait, vitals,
  information, inventory, the 4 by 3 command card, hero buttons, the
  idle-worker button, the message area and the Quests/Menu/Allies/Log
  panel. On a wide window they move in together; at 4:3 the whole
  layout scales.
- The sizes are `layout.lua`'s, fitted into 960 across. They are this
  project's, not measured from the game. The game's FDF files would give
  the real ones.

**API:**

- **`console.FRAMES`**: the data.
- **`console.compute(w, h)`**: returns the same table as
  `layout.compute(w, h)`, plus `scale` and the `screen` and `ui` roots.
  `hud.r` can take it in place of layout.lua's; the test draws the hud
  that way and presses a command button where the anchored card puts it.
- **`console.cache()`**: `:get(w, h)` works the table out on resize only.
