# 502 -- The bridge serves a browser

**Phase:** 5, the bridge and the browser
**Blocked by:** [501](501-the-bridge-holds-one-socket.md)
**Blocks:** [503](503-the-view-receives-state.md)
**Documents:** [the three programs](../../docs/002-the-three-programs.md)

## Current behaviour

The bridge holds a socket to the server. Nothing looks at it.

## Intended behaviour

An HTTP server on `localhost`, port 12345 by default, serving one page and one
websocket.

You run the bridge with the server's address; you open `localhost:12345`; you are
at the table. **You are not hosting anything** -- the world is on the host's
machine the whole time.

### Deliberately small

This serves a handful of files to one person on a loopback interface. It is not a
web server and must not grow into one.

| Does | Does not |
| --- | --- |
| `GET /` -- the page | Virtual hosts |
| `GET /view.js` etc. -- a fixed list of files | Directory listing, ever |
| `GET /socket` -- upgrade to a websocket | Uploads, cookies, sessions |
| Anything else -- 404, in one line | Compression, caching, ranges |

**A fixed list of files, not a directory.** Serving a path from a request means
handling `..` correctly forever; serving from a list means the question never
arises. Files are compiled into the binary, so a bridge is one file to copy and
there is nothing to install alongside it.

### The websocket

Enough of RFC 6455 to work and no more: the opening handshake, text and binary
frames, ping and pong, close. Masking from the client is mandatory and unmasking
is two lines.

The frames carry the same instructions the server sent, re-encoded -- so the
browser learns one format rather than two, and the bridge is a translator rather
than an interpreter.

## Suggested implementation steps

1. Bind `localhost` only -- **never** all interfaces. A bridge listening on a
   network is a web server on somebody's machine that they did not ask for.
2. Parse enough HTTP to find the method and path. Anything unrecognised is 404.
3. Serve from a compiled-in table keyed by exact path.
4. Implement the websocket handshake, then framing.
5. Write the companion `.info.md`.
6. Test the framing against captured bytes, including a frame split across two
   reads -- which is the case that works in testing and fails in use.

## What this deliberately does not do

No TLS. It listens on loopback, where browsers do not ask for it, and adding it
would mean certificates on every participant's machine for a connection that
never touches a network card.
