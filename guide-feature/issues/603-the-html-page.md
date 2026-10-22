# 603 — The HTML page

phase 6, viewers for the desk and the browser

## Current behavior

The page server answers plain text (204). Nothing turns it into something a
browser shows nicely.

## Intended behavior

A single HTML file, served by the page server at `GET /` (the one route
added beyond the protocol's three), with inline JavaScript that holds
`GET /page?after=N&box=WxH&viewer=browser` open, parses the page text in
JavaScript straight from `docs/page-protocol.md`, and draws the box with CSS
opacity and fade transitions. Its `box=` is measured from the window size in
characters.

This is the remote-access viewer. It works from any machine that can reach
kuvalu.

## Suggested implementation steps

1. The page and its parser.
2. Add `GET /` to the page server's route table, and to
   `docs/page-protocol.md`.
3. Check in Firefox at two window sizes, with screenshots.

## Related documents

- `docs/page-protocol.md`
- `docs/datapath-viewers.md`

## Open questions

- Reachable from outside the house, and with what password?
  (`docs/open-questions.md`, 8)

## Blocked by

204.

## Blocks

604.
