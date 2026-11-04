# 501 — The panel by the pointer

## Current behavior

Nothing exists. Needs `202`.

## Intended behavior

**What the reader sees: a small panel beside the quantity, holding the
sentence and then the picture.**

- It appears when the host sends `analogy`, showing the sentence at once with
  a quiet placeholder where the picture will be. The picture replaces the
  placeholder when `picture` arrives — however long that takes; there is no
  timeout that gives up on it.
- A quantity hovered before shows its cached sentence and picture at once
  (`403`); only a middle-click (`502`) replaces them.
- It sits beside the quantity, not under the pointer, and flips to the other
  side or above when it would run off the viewport.
- It disappears when the pointer has been away from both the quantity and the
  panel for a short time (a setting), so the reader can move onto the panel
  without losing it.
- `no_quantity` shows nothing. `exhausted` and `error` show their message in
  the panel, in words a reader can act on.

**It must not be restyled by the page it sits on.** A page's CSS reaches into
anything the extension inserts unless it is shielded, so the panel is built
inside a shadow root.

## Suggested implementation steps

1. `src/extension/` — the panel: build, place, fill, remove.
2. Test on pages with heavy styling (a news site, a wiki, a recipe blog) and on
   a dark-themed page.
3. Test placement at every edge of the viewport.

## Related

`docs/006-datapath-the-bridge.md` · needs `202` · blocks `502`, `503`
