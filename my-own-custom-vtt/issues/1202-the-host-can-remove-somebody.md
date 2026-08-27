# 1202 -- The host can remove somebody

**Phase:** 12, the table as it is actually played
**Blocked by:** phase 11 complete.
**Blocks:** [1203](1203-and-undo-what-they-did.md)
**Documents:** [the door and the private port](../docs/003-the-door-and-the-private-port.md)

## Current behaviour

The door admits whoever knocks and hands them a body. The join request carries a
`secret` field that nothing reads.

There is no way to remove somebody. A connection ends when the far end closes it
or the socket breaks.

## Intended behaviour

**Nothing checks who you are, and that is the decided answer** — not an oversight
waiting for a login system.

> Nothing. If the host wants to they can kick a player and roll back any actions
> taken.

That is how a real table works. Nobody at a kitchen table proves their identity;
somebody who behaves badly is asked to leave, and what they did is undone by
agreement. The program's job is to make both of those possible, not to prevent
the first from being necessary.

### But the answer is only honest if both halves exist

Neither did. "We do not need authentication because the host can remove somebody"
is a defensible position **only if the host can actually remove somebody**, and a
statement of that shape with nothing behind it is worse than no position at all.

This issue is the first half. [1203](1203-and-undo-what-they-did.md) is the
second.

### What removing somebody does

| Step | Why |
| --- | --- |
| Close their socket | They stop receiving. Their private port is released back to the range. |
| Unhold every scope they hold | Their bodies go back to being unheld, which is a normal state — the forest exists whether anybody is playing it. |
| Mark the viewer empty | So the slot is reusable and nothing keeps writing to a dead socket. |
| Say so, to everyone left | A person vanishing from the table with no announcement is a bug report waiting to happen. |

**Their bodies are not deleted.** Removing a person is not removing a character:
the party still has four members and one of them is now unheld. Deleting the body
would be the program making a decision about the fiction, which is not its job.

### Who may

Whoever may edit the world. The same gate as handing a scope over, and the same
reason: it is an act about the table rather than about a body.

### What it does not solve, said plainly

**They can knock again.** There is no ban list, no memory of who was removed, and
no way to have one without the identity this project has decided not to have.

At a table of friends on one machine that is fine, and the honest description of
the security model is: *anyone who can reach the port can join, and the host can
remove them.* Written down in
[the door and the private port](../docs/003-the-door-and-the-private-port.md)
rather than left for somebody to discover.

## Suggested implementation steps

1. `VERB_EVICT`, subject is the viewer being removed, gated by MAY_EDIT_WORLD.
2. A door function that closes a socket, releases the port and empties the slot.
3. Unhold their scopes -- `scope_unhold_all` already exists.
4. Refuse evicting yourself, by name. It is almost certainly a mistake and the
   recovery from it is restarting the server.
5. Test: the port is released and reusable; the scopes are unheld; the bodies
   still exist; and a viewer without MAY_EDIT_WORLD is refused.
