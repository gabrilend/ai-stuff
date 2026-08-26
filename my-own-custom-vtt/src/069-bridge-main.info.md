# 069-bridge-main

The program each participant runs. Two jobs and no others: hold one socket to the
server, and serve a browser on localhost.

```
069-bridge <address> <door-port> <name> [local-port]
```

Then open `http://localhost:12345`. **You are not hosting anything** — the world
stays on the host's machine; this holds a socket to it and a browser to you.

## It holds no authority

If the bridge and the server disagree about where a goblin is, the server is
right by definition. It does not simulate, does not filter, and does not remember
anything the server has not told it. It **translates**.

## Why it exists rather than the browser talking to the server

Four things, and the extra program is cheaper than all of them:

- **A browser must be served from somewhere.** Making the C server speak HTTP puts
  a web server inside the authoritative simulation. Here it is a separate process
  on the participant's own machine serving one person: themselves.
- **The connection would need TLS.** A browser talking to a remote host wants
  certificates; a browser talking to loopback is exempt, because browsers treat
  it as a secure context. A hard problem becomes a solved one.
- **The wire format would be stuck.** A browser speaks websockets and nothing
  else. Between two C programs the link can be the packed bytecode phase 4 built,
  because no browser has to parse it.
- **Per-person presentational work** happens on the participant's own CPU.

The honest cost: **everybody installs and runs a program**, not just a URL.

## The slot table is generated, not written twice

`build_tables_js` emits the opcode and slot widths as JavaScript at startup, read
from the same C table the encoder uses, and serves it as `/tables.js`.

Two copies of a grammar drift, and when they do the symptom is operands read at
the wrong offsets — which looks like corruption rather than like a mismatch, and
is very hard to recognise as either.

The refusal sentences come the same way, so a number can never arrive at a
browser with no sentence anywhere.

## Line-buffered output

`setvbuf` with `_IOLBF`. Redirected to a file, C buffers a whole block by
default — which makes a bridge that is running perfectly well look exactly like
one that hung on startup.

## What it does not do yet

**It only reaches a server on this machine**, and says so rather than failing
obscurely. Connecting across a network is the next thing this file needs.
