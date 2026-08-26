# 402 -- A session is a socket

**Phase:** 4, people connect
**Blocked by:** [401](401-the-door-hands-out-a-port.md)
**Blocks:** [404](404-one-function-writes-to-a-socket.md),
[406](406-commands-run-a-gauntlet.md)
**Documents:** [the door and the private port](../../docs/003-the-door-and-the-private-port.md),
[who controls what](../../docs/008-who-controls-what.md)

## Current behaviour

Nothing exists. The session in `053-session.c` has no participants.

## Intended behaviour

A **viewer**: one participant, one port, one socket, for as long as they are
connected.

| Field | Type | Meaning |
| --- | --- | --- |
| `port` | `uint16_t` | Theirs alone. The port number **is** the identity. |
| `socket` | `int` | The accepted connection. |
| `address` | `uint32_t` | Where the join request came from; a connection on this port from anywhere else is refused. |
| `name_offset` | `uint32_t` | What they are called at the table. Display only, never used to decide permission. |
| `fog` | index | Their memory. One per viewer. |
| `state` | `uint8_t` | `WAITING`, `CONNECTED`, `GONE`. |

Viewers live in a block like everything else, so index 0 is "nobody" and the
outbound filter can hold a viewer index without a null check.

### The identity question is answered before our code runs

Bytes arriving on a port belong to whoever that port was bound for. The operating
system decided that, using code that has been correct for thirty years -- there is
no session-token lookup in the receive path, so there is no bug possible in one.

**This is the property phase 4's entire security argument leans on**, and it is
why one port per participant was chosen over one port and many sockets. It should
be commented where the socket is bound, because it is the reason for a cost the
host pays at their router.

### Reading without blocking

The tick cannot wait on a socket. Draining is non-blocking, bounded per viewer per
beat, and a viewer with nothing to say costs one failed read.

A **bound on bytes per beat** matters: without it, one participant flooding the
socket starves every other viewer's intake for as long as they keep it up.

### Going away

A closed socket, an error, or a silence longer than a timeout marks a viewer
`GONE`. Their port is released and their scopes become unheld.

What happens to their character, and whether their fog survives a reconnect, is
[4.4](../../docs/016-open-questions.md) and is not answered. **Fog surviving a
reconnect is the difference between a dropped connection being an annoyance and
being a disaster**, so this should be decided rather than defaulted into.

## Suggested implementation steps

1. Add the viewers block to the world, with its sentinel.
2. Accept on a private port and check the address matches the join.
3. Write the non-blocking drain, with the per-beat byte bound.
4. Wire viewer creation to fog creation -- one fog per viewer, sized from the
   world, allocated once.
5. Detect departure three ways: clean close, error, and timeout.
6. Write the companion `.info.md`.
7. Test: connect, send, drop, reconnect; a flood hitting the per-beat bound; a
   connection from the wrong address.
