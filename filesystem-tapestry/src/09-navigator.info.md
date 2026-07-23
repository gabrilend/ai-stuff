# 09-navigator.lua — info

The front door of the viewing half: a cursor over an ordering, plus a
word→function command table. A module; the entry script (`10-main.lua`) drives
it.

## External functions

- `run(records, config, startup) -> ending` — build a Navigator, print the
  opening view, and run the read-a-word/do-a-thing loop until `quit` or EOF.
  `startup` may pre-set `{ mode, field, direction }`. Returns
  `{ mode, cursor, total, path }` describing where the walk ended (the entry
  script writes it into `output/goodbye`).
- `Navigator.new(records, config, startup) -> nav` and its methods
  (`move`, `open`, `where`, `list`, `set_mode`, `set_field`, `reverse`,
  `rebuild`) — exposed for tests or an alternate front end.

## Commands (the whole grammar)

`next/n`, `previous/prev/p`, `open/o`, `where/w`, `list/l`,
`chronological`, `similar`, `different`, `created`, `modified`, `reverse`,
`help/h/?`, `quit/q`. An empty line steps forward, like turning a page.

## Behaviour notes

- Switching walks keeps the cursor on the **same file** where possible
  (`rebuild` re-anchors), so you do not lose your place.
- `open` uses the media dispatch table. Terminal viewers (neovim) run in the
  foreground; windowed viewers detach with output sent to `tmp/viewer.log`. An
  unknown kind falls back to `xdg-open` **with a printed warning**.
- Excluded files are already absent from the browse ordering, so `next`/
  `previous` never strand you in a cache directory.
