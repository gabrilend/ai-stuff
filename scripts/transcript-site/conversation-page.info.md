# conversation-page.lua

Turns one conversation (from `transcript-reader.lua`) into one finished HTML
page.

## Public functions

- `render(conversation, opts) -> string` — a whole HTML document. `opts`:
  - `title` (string) names the page;
  - `back` (string) is the link home;
  - `base_path` (string, default `"."`) is the route to the folder holding
    `fonts/`;
  - `palette_file` (string path) is the colours; default
    `default-palette.lua`;
  - `anchor = false` turns off the `id="turn-N"` on each turn, and with them
    the Contents links.
- `summary_line(text, width) -> string or nil` — text flattened to one line
  and cut on a word boundary.
- `stylesheet() -> string` — the page's own CSS rules.
- `default_palette_file() -> string` — the path of `default-palette.lua`.

## What the page shows

- The person on the left in green, the assistant on the right; the model
  named only where it changes.
- **"How it went"**: the recap Contents list at the top, each entry linking to
  the turn after its request.
- The harness's summary after a conversation runs out of room, folded away;
  lines above the first request, centred and quiet.
- Links to a sibling transcript (`x.md`, a helper's) point at its page
  (`x.html`); every other link is left as written.
- "date not recorded" / "models not recorded" for an archived transcript,
  "no model named" for one whose replies named none.

It redacts nothing and runs no script.
