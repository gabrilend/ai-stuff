# 025-canvas-server — info

The HTTP canvas server (issue 204): the one program the router forwards a
port to from outside (`docs/network.md`). It is its own process. It reads
only `tmp/shared-memory/canvas/` (203), and learns of a new version by
reading `canvas/current`'s first line every `check-seconds`.

    luajit src/025-canvas-server.lua [--dir ROOT]
    scripts/run-canvas-server [ROOT]        Ctrl-C or TERM stops it cleanly

| Request | Answer |
|---|---|
| `GET /canvas` | 200, the newest version (404 before there is one) |
| `GET /canvas?after=N` | the newest version once it is above N, or 204 after `wait-seconds` |
| `GET /canvas/N` | 200, version N from history, or 404 |
| `GET /` | 404 until the HTML page (803) exists |
| anything else | 404; another method on a route, 405 (`Allow: GET`) |

Limits, in `input/canvas-server`:
- `max-connections` (beyond it, 503);
- `max-request-bytes` (413);
- `request-seconds` for a request to arrive (408).

Every answer closes its connection. The socket is shut for sending and
drained for up to a second before it is closed, so a client never loses an
answer to a reset connection.

Each connection is a coroutine on one LuaSocket `select` loop. It yields
`"read"` while its request arrives and `"wait"` while it waits for a
version.

Each request from an address not in `local-addresses` gets one log line:
address, request line (or `-`), answer.

The receipt counts:
- `requests-<route>` (`canvas`, `canvas-after`, `canvas-version`, `page`);
- `waits-answered`, `waits-timed-out`, `waits-abandoned`;
- `refused-<reason>` (`not-found`, `method`, `too-large`, `too-slow`,
  `too-many`).

It stops cleanly on `tmp/shared-memory/canvas-server.stop`, which the
wrapper drops on INT or TERM.

`opts.seal` is the seam for the encrypted canvas (803, owner's machine): a
function from the canvas text to the body sent. Until then the text is sent
as it is, and the start of the log says so.
