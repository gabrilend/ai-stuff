# 501 -- The bridge holds one socket

**Phase:** 5, the bridge and the browser
**Blocked by:** phase 4 complete.
**Blocks:** [502](502-the-bridge-serves-a-browser.md)
**Documents:** [the three programs](../docs/002-the-three-programs.md)

## Current behaviour

The server fills a buffer with exactly what one participant may know. Nothing
carries it anywhere.

## Intended behaviour

A small C program on each participant's own machine that does exactly two things:
holds one socket to the server, and serves a browser on `localhost`.

**It holds no authority.** If the bridge and the server disagree about where a
goblin is, the server is right by definition and the bridge discards what it
thought.

### Why it exists at all

The obvious design is to delete it and let the browser open a websocket straight
to the server. Four things make the extra program cheaper than it looks:

**The browser has to be served from somewhere.** A browser will not open a page
out of nothing. Making the C server speak HTTP means putting a web server inside
the authoritative simulation -- the single largest source of remote
vulnerabilities you could choose to add to it. With the bridge, the HTTP server
is a separate process on the participant's own machine serving exactly one
person: themselves.

**The connection would need securing.** A browser talking to a remote host over a
websocket wants TLS -- certificates, a domain name, or teaching every participant
to click through a warning. A browser talking to `localhost` is exempt, because
browsers treat loopback as a secure context. The bridge converts a hard problem
into a solved one.

**The wire format would be stuck.** A browser speaks websockets and HTTP and
nothing else. Between two C programs the link can be whatever is best -- which is
exactly the packed bytecode phase 4 built. The bridge translates, so the server's
protocol is free to be efficient because no browser has to parse it.

**Per-person work would land on the host.** The parts that are merely
presentational can happen on the participant's own CPU.

The cost is honest: **every participant installs and runs a program.** Not just a
URL. That is the price of the four above.

## Suggested implementation steps

1. Take an address, a door port, and a name on the command line.
2. Do the join handshake, get a private port, connect to it.
3. Read instructions and keep the latest world state in memory -- the newest
   update is the whole picture, so holding one is enough.
4. Send commands the other way.
5. Reconnect, or report clearly and stop. Do not silently retry forever; a bridge
   that is quietly not connected looks exactly like a server that is quietly not
   sending.
6. Write the companion `.info.md`.
