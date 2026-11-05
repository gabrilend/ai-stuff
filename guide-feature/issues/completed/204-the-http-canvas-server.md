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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Each connection is a coroutine on one LuaSocket `select` loop.** It
   yields while its request is arriving or while it waits for a version.
   Routes are a table of `{ name, match, handle }`, tried in order.
2. **It notices a new version by reading `canvas/current`'s first line**
   every `check-seconds` (0.2), since there is no inotify binding here, as
   in 107. So the blitter and the server can each be restarted alone, and
   a wait is answered across a blitter restart, because version numbers
   carry on (203).
3. **Every answer closes its connection; there is no keep-alive.** That
   keeps the connection count honest, and a viewer opens one per request.
   An answered socket is shut for sending and drained for up to a second
   before it is closed, so the client never loses its answer to a reset.
4. **Answers:**
   - a method other than `GET` on a route: `405` with `Allow: GET` (`HEAD`
     included);
   - a path or query that is no route: `404`;
   - a number with a leading zero (`/canvas/02`, `?after=01`): `404`, as
     the canvas format refuses `018`;
   - too large: `413`; too slow to arrive: `408`;
   - one connection over the limit: answered `503` and closed;
   - `GET /canvas` before there is any canvas: `404`;
   - `GET /`: a `404` naming 803 until the page exists.
5. **The limits and the wait are settings in `input/canvas-server`**, with
   these values:
   - `max-connections` 32, `max-request-bytes` 4096, `request-seconds` 5;
   - `wait-seconds` 60, as the protocol says; `check-seconds` 0.2;
   - `listen-address` `0.0.0.0`, for the router's forwarded port;
   - `port` 20170, a placeholder until 401a picks the project's ports.
     `0` takes any free port, and the log names it, which is how the tests
     run.
6. **"The four machines" are a setting, `local-addresses`** (kuvalu, the
   three fg-sora, and 127.0.0.1, from `docs/architecture.md`). A request
   from anywhere else gets one log line: address, request line (or `-` if
   none arrived), answer (or `closed` if the client left).
7. **It stops cleanly on `tmp/shared-memory/canvas-server.stop`**, dropped
   by `scripts/run-canvas-server` on INT or TERM, as the blitter's wrapper
   does. LuaJIT can't catch signals.
8. **The encrypted canvas is behind a seam.** `opts.seal` takes the canvas
   text and gives the body sent. Until the HTML page (803) brings the
   AES-256-GCM scheme in the answered question above, the canvas is sent as
   plain text, and the server's log says so at start. The keys, the
   password set-up and the router's forwarded port need the owner's
   machine.

## Implementation notes (2026-11-05)

- `src/025-canvas-server.lua`: the program and library.
- `scripts/run-canvas-server`: the wrapper.
- `input/canvas-server`: the server's settings.
- `src/026-test-canvas-server.lua`: 30 pass, about 15 seconds, on 127.0.0.1
  only. It was run three times in a row, with no flakes.
- Mutation checks were each caught:
  - no connection limit, no size limit, no arrival deadline;
  - `after` off by one, or allowing a leading zero;
  - any method allowed;
  - `wait-seconds` ignored;
  - local addresses logged;
  - an abrupt close;
  - the body altered;
  - a new version not noticed;
  - a hang-up not noticed.
- `docs/canvas-protocol.md` and `docs/network.md` describe what was built.
  `.file-index-counter` is at 026.

**Checked here:** with LuaSocket 3.0.0, LuaJIT 2.1 and curl, on 127.0.0.1
only.

**Needs the owner's machine:**
- the server running on kuvalu at its real port, and the router
  forwarding that one port to it;
- requests from outside the home network;
- the encrypted canvas with its keys and password set-up (with 803).
