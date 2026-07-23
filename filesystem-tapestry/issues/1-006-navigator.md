# 1-006 — Navigator

## Phase 1: The Thread

## Current Behavior

A catalog can be built and ordered, but there is no way to *walk* it or open the
file you are standing on.

## Intended Behavior

The viewing half's front door: an interactive cursor over an ordering.

Commands:

- `next` / `n` — advance the cursor along the active ordering, skipping excluded
  records (browse mode).
- `previous` / `prev` / `p` — retreat the cursor, same skipping.
- `open` / `o` — hand the current record to the program from the media dispatch
  table; unknown kinds fall back to `xdg-open` with a warning.
- `chronological` / `similar` / `different` — switch the active ordering
  (similar/different fall back to chronological with a warning until Phase 2).
- `created` / `modified` — choose which date chronology sorts on.
- `reverse` — flip ascending/descending.
- `where` / `w` — print the current record (path, both dates, kind, size).
- `quit` / `q` — write goodbye to output/ and exit.

Lifecycle, per project convention:

- **First** thing on startup: read `input/` (any file there can pre-set the
  starting ordering, date field, or direction).
- **Last** thing on quit: write `output/goodbye` recording where the walk ended.

The command loop is a **dispatch table** (command string → handler function),
never a switch ladder.

## Suggested Implementation Steps

1. Load the catalog via `src/04-catalog-store.lua`.
2. Build the active ordering via `src/05-ordering-engine.lua`.
3. Hold `cursor` (offset into the ordering) and `mode` state.
4. `COMMANDS` dispatch table; read a line, look it up, call it.
5. `open` shells out to the dispatch-table viewer, detached, so the navigator
   stays responsive.
6. On quit, write `output/goodbye`.

## Related

- `src/09-navigator.lua` (implementation)
- `src/04-catalog-store.lua`, `src/05-ordering-engine.lua`,
  `libs/08-media-dispatch.lua`

## Metadata

- Status: In progress
- Phase: 1
- Blocks: (capstone of Phase 1)
