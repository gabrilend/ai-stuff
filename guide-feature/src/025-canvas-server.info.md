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
| `GET /` | 200, the HTML page (803, `077-html-page.html` with the libraries put in) |
| `GET /session?viewer=NAME` | 200, a fresh session key locked with that viewer's key (`076-html-page.info.md`); 404 for no such viewer |
| `...&session=ID` on any canvas route | the canvas locked with that session's key, as hex; 403 for a session that has ended |
| anything else | 404; another method on a route, 405 (`Allow: GET`) |

Without a session, the canvas goes as plain text only where `send-plain`
says: `local` (the `local-addresses`), `everyone` or `nobody`. Elsewhere it
is 403, saying to open the page. The viewers file (`viewers-file`, outside
the project) is read again at every sign-in.

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
- `requests-<route>` (`canvas`, `canvas-after`, `canvas-version`, `page`,
  `session`);
- `sessions-started`;
- `waits-answered`, `waits-timed-out`, `waits-abandoned`;
- `refused-<reason>` (`not-found`, `method`, `too-large`, `too-slow`,
  `too-many`, `plain`, `no-session`, `no-viewer`).

It stops cleanly on `tmp/shared-memory/canvas-server.stop`, which the
wrapper drops on INT or TERM.

Its start in the log names the viewers and who gets plain text.
