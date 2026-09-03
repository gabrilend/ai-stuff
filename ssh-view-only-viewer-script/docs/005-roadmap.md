# Roadmap

Phases group functionality, not time. The numbering says what builds on
what; the last issue closed will not be the highest-numbered one.

## Phase 1 — The arrangement

What a valid packet looks like, and how the listening machine tells a
genuine one from noise, from a stranger's guess, and from a copy of a
packet it already honoured.

Pure reasoning about bytes. No privileges, no network required to test
it, no knowledge of what happens afterwards. It is first because
everything downstream is triggered by its verdict, and a grant that fires
on a bad verdict is the worst failure this project has.

Issues: `100`–`1xx`. Datapath: [the arrangement](001-the-arrangement.md).

## Phase 2 — The grant

Bringing a credential into existence on receipt of a good verdict, and
taking it away when its time is up. The part that needs root.

Ends with an account that appears when a packet arrives and is gone
afterwards, whether or not anyone used it, and whether or not the process
that made it is still running.

Issues: `200`–`2xx`. Datapath: [the grant](002-the-grant.md).

## Phase 3 — The room

What the visitor can reach and what they can do there. A chroot they
cannot climb out of, sshd's read-only mode, and the choice of which part
of the filesystem is exposed.

Depends on phase 2 for someone to let in.

Issues: `300`–`3xx`. Datapath: [the room](003-the-room.md).

## Phase 4 — The refill loop, an example

r-mail carrying a random file to a viewer, and the viewer's deletion
asking for the next one. An **example of what to show someone** once the
first three phases can show them anything at all.

Deliberately last, and deliberately unable to be depended upon. If any of
phases 1 through 3 ever needs something from here, the separation has
failed.

Issues: `400`–`4xx`. Datapaths:
[the refill loop](004-the-refill-loop.md), [the draw](008-the-draw.md).

## Phase 5 — Watching it work

The demos, which are part of the deliverable rather than a development
artifact. A packet sent and an account appearing; the account vanishing
on schedule; a session trying to write and being refused; the example
loop running beside it.

Issues: `500`–`5xx`.
