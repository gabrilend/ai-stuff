# conversation-page.lua

Part of the transcript display. Turns one conversation (from
`transcript-reader.lua`) into one finished HTML page. Loads the shared
libraries and nothing from the other parts.

## Public functions

- `render(conversation, opts) -> string` — a whole HTML document.

  | option | type | what it is |
  | --- | --- | --- |
  | `title` | string | names the page |
  | `back` | string or nil | the link home |
  | `base_path` | string, default `"."` | route to the site root, where `fonts/` and `films/` are |
  | `colours_css` | string, required | a `:root { }` block of the colours; refused when missing, since every colour would resolve to nothing and the page would look blank |
  | `films` | list or nil | one per exchange: a film's file name (string) or false |
  | `film_size` | whole number, default 64 | the film's side, CSS pixels |
  | `anchor` | false to turn off | the `id="turn-N"` on each turn, and the Contents links |

- `commit_anchor(hash) -> string` — the id a commit line carries,
  `commit-<first seven>`. The one name the table of contents shares with
  this page; the builder hands it across.
- `summary_line(text, width) -> string or nil` — text flattened to one line
  and cut on a word boundary.
- `stylesheet(uses) -> string` — the page's rules. `uses.harness` and
  `uses.contents` (booleans) add those optional rules; no `uses` means all.
- `STYLE_TOP`, `STYLE_HARNESS`, `STYLE_CONTENTS`, `STYLE_BOTTOM` — the four
  pieces, in order.

## What the page shows

- Her words on the left in green, the assistant's on the right; the model
  named only where it changes.
- A film beside each message when given: hers on the left, the assistant's
  on the right and mirrored, in the margin outside the reading column; back
  inside the column on a window narrower than 1200 pixels.
- Every commit line `*[commit] <hash> ...*` gets its id, and lights up when
  a reader lands on it.
- **"How it went"**: the recap Contents list at the top, each entry linking
  to the turn after its request.
- The harness's summary after a conversation runs out of room, folded away;
  lines above the first request, centred and quiet.
- Links to a sibling transcript (`x.md`) point at its page (`x.html`).
- "date not recorded" / "models not recorded" for an archived transcript,
  "no model named" for one whose replies named none.

## Only the rules it uses

The Contents and harness rules join the stylesheet only on a page that draws
them. That keeps double-diaper-dungeon's pages, which draw neither, byte for
byte what they were.

It redacts nothing and runs no script.
