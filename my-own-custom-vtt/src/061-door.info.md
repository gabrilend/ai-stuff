# 061-door

One port that is always open, and a range it hands out.

There is one number a participant must be told in advance: the door. They connect
to it, say who they are, and are given a port of their own. Then the door closes
the conversation — **it is a receptionist, not a room.**

This is the only file in the server that knows what a socket is.

## The functions

| Function | Purpose |
| --- | --- |
| `door_open` | Bind the door and reserve the range. Fails with a **sentence**, so a host knows which number to change. |
| `door_close` | |
| `door_admit` | Accept joins without blocking; claim a port; bind a listening socket; make a `WAITING` viewer. |
| `door_connect_waiting` | Accept the private connections, checking each came from the join's address. |
| `door_drain` | Read into inbound buffers, bounded per viewer per beat. Marks departures. |
| `door_flush` | Write outbound buffers. |
| `join_sentence` | Every outcome as words. |
| `door_ports_in_use` | |
| `door_join_as_client` | A test client, so a demo runs several participants in one process. A demo needing three terminals is a demo nobody runs. |

## Permission is not in the request

A client cannot ask to be a GM. The server looks up what somebody may command and
informs them — enforced by the request having **no field for it** rather than by
a check that could be forgotten.

## Refusals are answered, then the socket closes

A silent drop would leave somebody who mistyped a password unable to learn that
they mistyped a password. Every outcome has a sentence, including
`JOIN_RANGE_FULL`, which tells a host to **widen the range** rather than saying
"cannot join".

A wrong magic costs one comparison — the point of having one is that a stray port
scanner is turned away before anything else is read.

A name past `JOIN_NAME_MAX` is refused, not clamped: clamping would leave the
rest of the name in the stream to be read as something else.

## The private connection is checked against the join's address

The port is the identity, and somebody else connecting to it would be somebody
else wearing it.

## `SO_REUSEADDR`

Without it a port stays unusable for a minute or two after the server stops,
which turns "restart the server" into "wait, then restart the server" — the
single most annoying thing about writing one.

## What a full send window does

The rest of the update is dropped rather than queued, because **an update is the
whole picture rather than a difference** — a missed one costs a beat of freshness
and nothing else.
