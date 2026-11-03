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

Port and listen address come from `input/canvas-server` (101).

It is the "narrow cause-way at a castle": the router forwards one port from
outside to it and to nothing else (`docs/network.md`). So it is built narrow,
as listed in "Keeping the causeway narrow" there:

- read-only: it has only the routes above, and nothing sent to it changes
  anything;
- it reads only `tmp/shared-memory/canvas/`, and holds no rmail secrets and
  no endpoint keys;
- limits on open connections, request size, and how long a request may take
  to arrive, so slow or many requests cannot tie it up;
- one log line per request from outside the four machines: address, route,
  answer.

## Suggested implementation steps

1. The socket loop, one coroutine per open request.
2. Routes as a table from path to handler.
3. The limits, each a setting.
4. Tests with `curl`: each route, a waiting request answered by a new
   version, a wait timing out, a bad route, a `POST` refused, an oversized
   request refused, too many connections refused.
5. Goodbye counters: requests by route, waits answered, waits timed out,
   requests refused by reason.

## Related documents

- `docs/canvas-protocol.md`, "Over HTTP"
- `docs/network.md`

## Open questions

- Answered: the canvas it serves is encrypted with AES-256-GCM, and the
  page decrypts it in JavaScript with a key from after the `#` in its
  address. The server never holds that key in any page it sends. Each browser
  session has its own key, separate from the rmail secrets; viewers set up
  their password-key on the server beforehand. For a password
  viewer, the server sends the session's fresh key locked with that
  viewer's key; the password itself never crosses the network.

## Blocked by

101, 203.

## Blocks

206, 803, 901, 902.
