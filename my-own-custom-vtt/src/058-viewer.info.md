# 058-viewer

One participant, one port, one socket.

**The port number is the identity.** Bytes arriving on a port belong to whoever
that port was bound for, and the operating system decided that using code correct
for thirty years. There is no session-token lookup in the receive path, so there
is no bug possible in one.

That property is what phase 4's security argument leans on, and it is why one
port per participant was chosen — and why a host pays for a forwarded range.

## A correction to the documents

`docs/004-the-world-and-its-tick.md` lists `viewers` among the world's blocks.
That is right in one respect and wrong in another:

- A viewer's **identity** is world state — a scope names a viewer, and scopes are
  part of the world, so the index must be stable and snapshottable.
- A viewer's **socket** is not. Putting a file descriptor in a snapshot would mean
  a rollback restoring a connection, which is nonsense: taking a turn back does
  not un-send bytes.

So viewers live beside the session rather than inside the world, and the index is
what phase 6's scopes will refer to.

## The record

| Field | Meaning |
| --- | --- |
| `state` | `EMPTY`, `WAITING`, `CONNECTED`, `GONE`. |
| `port` | Theirs alone. |
| `socket` | `-1` when not connected. |
| `address` | Where the join came from; another address on this port is refused. |
| `name_offset` | Display only. **Never** used to decide permission. |
| `fog` | Their memory. One per viewer, sized from the world, allocated once. |
| `inbound` / `outbound` | Buffers. |
| counters | Bytes, refusals, things and walls sent — what a demo reports. |

Index 0 is nobody, like every other block, so nothing anywhere needs a null check
on a viewer. A scope with viewer 0 is a scope nobody holds — the normal state of
the forest on an evening when nobody is playing it.

## `VIEWER_INTAKE_PER_TICK`

A bound on bytes read from one participant per beat. Without it, somebody
flooding their socket starves every other viewer's intake for as long as they
keep it up — not by exploiting anything, just by talking a lot.

## Departing keeps the fog

The socket goes and the buffers empty. **The fog stays.**

Whether it should is open question 4.4, left standing rather than decided here:
fog surviving a reconnect is the difference between a dropped connection being an
annoyance and being a disaster, and somebody who drops for thirty seconds should
not have to re-explore an evening's dungeon.

Keeping it costs a few kilobytes per departed viewer and is the reversible
choice. Throwing it away is not.

## No socket code here

A viewer holds a descriptor and does not know how it got one. `061-door` binds
and accepts; this file is about what a participant *is*.

That separation is what lets the filter be tested exhaustively without a network,
which is what makes the leak test cheap enough to run on every build.
