# 144-the-viewer.lua

The viewer without its window (docs/067, issue 810; docs/010 question 11):
the pool as a gallery, keys by name, and each frame as a draw list a
window draws. Reads only cards, ratings and the floor table through 076;
shares no code with any maker. The raylib window, a thin front, waits on
raylib being vendored into `libs/`.

| Function | In | Out |
|---|---|---|
| `gallery(pool_dir)` | the pool | `{{asset, name, category, kind, tier, ratings}}`, sorted by category then name; exactly the assets 076's count utility counts |
| `in_use(entry, floors)` | an entry; the floor table | whether its category's floor keeps it in use (floor 0 keeps all; else rated at or above it) |
| `open(pool_dir, width, height, look)` | the pool; the window's size (default 1280×800); a look (default 070's) | the viewer's state |
| `key(state, key)` | the state; a key name: `1`-`5`, `left`, `right`, `up`, `down`, `[`, `]`, `y`, `q` | the state, after rating the selection (076's `rate`, by a person), moving, proposing a floor (its cost on the status line), setting a proposed floor, or quitting |
| `frame(state)` | the state | the draw list: `{op = "clear", colour}`, `{op = "rect", x, y, w, h, colour, filled}`, `{op = "image", path, x, y, w, h}`, `{op = "text", text, x, y, size, colour}` |
| `columns(state)` | the state | how many tiles fit across |
| `kind_of(path)` | an asset's path | `still`, `clip`, `text` or `source`, by its ending |
| `KINDS_BY_ENDING`, `GROUNDS`, `INK`, `TILE`, `GAP`, `LABEL`, `STATUS` | | the tables and sizes above |
