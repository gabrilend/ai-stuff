# 401 -- The door hands out a port

**Phase:** 4, people connect
**Blocked by:** phase 3 complete.
**Blocks:** [402](402-a-session-is-a-socket.md)
**Documents:** [the door and the private port](../docs/003-the-door-and-the-private-port.md)
**Open questions:** [4.2](../docs/016-open-questions.md) -- what is in the
`secret` field? [4.3](../docs/016-open-questions.md) -- how large can a table get?

## Current behaviour

Nothing listens. A session is driven by a scripted command file.

## Intended behaviour

One port that is always open and always the same -- **the door** -- and a range of
private ports it hands out, one per participant.

The sequence:

1. The client connects to the door and sends a **join request**.
2. The server checks the claim. A failure is a sentence saying what was wrong,
   then the socket closes. There is no silent drop: somebody who mistyped a
   password must be able to learn that they mistyped a password.
3. On success the server picks an unused port from the range, binds a listening
   socket to it, and records that the port belongs to this participant and to no
   one else.
4. The server replies with the port number and closes the door connection. **The
   door holds no session; it is a receptionist, not a room.**
5. The client connects to the port it was given. The server accepts exactly one
   connection there and checks it came from the address the join request came
   from.

### Permission does not travel in the join request

A client cannot ask to be a GM. The server looks up what this participant is
allowed to command from its own configuration and *informs* them.

That is the difference between a permission model and a suggestion box, and it is
enforced by the request having **no field for it** rather than by a check that
could be forgotten.

### Reclaiming a port

A port is released when its socket closes, and a port that was bound but never
connected to is released after a timeout. Both must be built rather than assumed.

When the range really is full, the refusal **says the range is full and names the
range** -- not "cannot join", which tells a host nothing about which number to
change.

## Suggested implementation steps

1. Bind the door. One listening socket, from configuration.
2. Read the join request with a hard bound on every length. A length past the
   bound closes the socket rather than being clamped -- that is not a mistake.
3. Refuse a wrong magic immediately, so a stray port scanner costs one comparison.
4. Refuse a version mismatch **naming both versions**.
5. Allocate from the range, with the reclaim policy built in from the start.
6. Write the companion `.info.md`.
7. Test: a good join; a bad magic; a version skew; a full range; a port bound and
   abandoned; two participants racing for the last port.

## What this does not do

No encryption and no real authentication yet. [4.2](../docs/016-open-questions.md)
is unanswered, and building a `secret` check before deciding what a secret is
would mean building the wrong one.
