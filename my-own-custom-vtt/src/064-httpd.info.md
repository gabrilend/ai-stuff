# 064-httpd

The smallest thing that can hand a browser a page and a socket.

Runs inside the **bridge**, on the participant's own machine, listening on
loopback and serving exactly one person: themselves. That is why it may be this
small — an HTTP bug here compromises somebody who already had the files.

**It is not a web server and must not grow into one.**

| Does | Does not |
| --- | --- |
| `GET /` and a fixed list of files | Virtual hosts |
| `GET /socket` — websocket upgrade | Directory listing, ever |
| Anything else — 404, one line | Uploads, cookies, sessions, compression |

## Two decisions that remove whole categories of bug

**A fixed list, not a directory.** Serving a path from a request means handling
`..` correctly forever; serving from a compiled-in table keyed by exact path
means the question is never asked. A test fetches `/../secret` and gets a 404
that does not mention what it was looking for.

**Loopback only, never `INADDR_ANY`.** A bridge listening on a network interface
is a web server on somebody's machine that they did not ask for. A test calls
`getsockname` and asserts the bound address, rather than inferring it.

## The functions

| Function | Purpose |
| --- | --- |
| `httpd_start` | Fails with a **sentence**, so somebody whose bridge will not start knows whether the port is taken. |
| `httpd_stop` | |
| `httpd_poll` | Accept, serve, upgrade, and read frames. Never blocks. |
| `httpd_broadcast` | A binary frame to every attached browser. |
| `httpd_client_count` | |
| `sha1_digest`, `base64_encode` | Exposed because they are worth testing directly. |

## SHA-1 and base64 are here rather than borrowed

Not for security — the browser's handshake key is not a secret and neither is
the answer. It is a handshake, and this is the arithmetic it specifies.

They are written out because **the bridge is meant to be one file to copy**. A
borrowed implementation is a dependency to install on every participant's
machine, and sixty lines of a frozen specification is cheaper than that.

Both are tested against **published vectors** rather than against themselves,
including the RFC 6455 worked example. An implementation that agrees with its own
bug produces a browser that silently never connects, with nothing to look at.

## Frames arrive in pieces, and two arrive at once

Both are normal, and a decoder assuming otherwise works in testing and fails in
use. `read_frames` accumulates bytes and consumes **whole** frames, leaving any
partial one where it is.

A payload larger than the buffer hangs up rather than growing forever.
