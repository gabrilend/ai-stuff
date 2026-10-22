# 204 — The HTTP canvas server

phase 2, the canvas for viewers

## Current behavior

The canvas exists only as files on kuvalu (203).

## Intended behavior

A small HTTP server on kuvalu answering the requests in
`docs/canvas-protocol.md`: `GET /canvas`, `GET /canvas?after=N` (held open
up to 60 seconds, then `204`), `GET /canvas/N`, and `GET /` for the HTML
viewer once 803 exists. Everything else is `404`.

It is a separate program from the blitter, and learns of new versions by
watching `tmp/shared-memory/canvas/current`, so either can be restarted
alone. Waiting requests are coroutines on one LuaSocket loop. LuaSocket is
already on kuvalu for rmail.

Port and listen address come from `input/canvas-server` (101). Under the
owner's router rules only the four machines can reach it
(`docs/network.md`).

## Suggested implementation steps

1. The socket loop, one coroutine per open request.
2. Routes as a table from path to handler.
3. Tests with `curl`: each route, a waiting request answered by a new
   version, a wait timing out, a bad route.
4. Goodbye counters: requests by route, waits answered, waits timed out.

## Related documents

- `docs/canvas-protocol.md`, "Over HTTP"
- `docs/network.md`

## Open questions

- How remote viewers reach it (`docs/open-questions.md`, 2).

## Blocked by

101, 203.

## Blocks

206, 803, 901, 902.
