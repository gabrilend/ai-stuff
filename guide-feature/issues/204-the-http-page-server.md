# 204 — The HTTP page server

phase 2, the page protocol

## Current behavior

Pages exist only as files on kuvalu (203). Nothing off kuvalu can read them.

## Intended behavior

A small HTTP server on kuvalu answering exactly the three requests in
`docs/page-protocol.md`: `GET /page`, `GET /page?after=N` (held open up to
60 seconds, then `204`), `GET /page/N`, each optionally carrying
`box=WxH` and `viewer=NAME`. Everything else is `404`.

It runs as its own program, separate from the page keeper, and learns of
new pages by watching `tmp/shared-memory/page/current`. A crash in one
cannot take down the other, and the HTTP server can be restarted alone.

It records the `box=` and `viewer=` of each request, with the time, in
`tmp/shared-memory/viewers`, one line per viewer. The box rules (205) read
that file.

Port and listen address come from `input/page-server` (101). Waiting
requests are served by coroutines on one socket loop, using LuaSocket (which
rmail also needs, so it is already on kuvalu).

## Suggested implementation steps

1. The socket loop with one coroutine per open request.
2. The three routes, a table from route to handler.
3. Tests with `curl`: each route, a waiting request answered by a new page,
   a waiting request timing out with `204`, a bad route.
4. Goodbye counters: requests by route, waits answered, waits timed out.

## Related documents

- `docs/page-protocol.md`, "From anywhere: HTTP"

## Open questions

- Which port, and reachable from outside the house or not?
  (`docs/open-questions.md`, 8)

## Blocked by

101, 203.

## Blocks

205, 206, 603, 701, 702.
