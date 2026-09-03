# Roadmap

Phases group functionality, not time. The numbering says what builds on
what; the last issue closed will not be the highest-numbered one.

## Phase 1 — The draw

The shared spine. A supplier that answers *give me a file, at random,
that I am allowed to lend*, knowing nothing about who asked. Both visions
consume it, so it is built first and alone.

Carries the corpus boundary, which is the only real security mechanism in
the project. Carries the repeat ceiling, which is what stops a viewer who
deletes forever from accumulating a complete copy.

Issues: `100`–`1xx`. Datapath: [the draw](002-the-random-draw.md).

## Phase 2 — The jail

The tooling vision. A chrooted, shell-less SFTP room per viewer, holding
one drawn file, refilling when emptied. Depends on phase 1 for its
contents and on nothing else.

Ends with a room a person can SSH into, empty, and watch refill.

Issues: `200`–`2xx`. Datapath: [the jail](003-the-sandbox-jail.md).

## Phase 3 — The refill loop

The implementation vision. The same draw carried by r-mail: an outbox
file per viewer, a deletion travelling backwards, a hook that notices and
writes the next one. No SSH.

Depends on phase 1. Independent of phase 2 — either can be built without
the other, which is the test of whether the two visions really were
separate.

Issues: `300`–`3xx`. Datapath: [the refill loop](004-the-refill-loop.md).

## Phase 4 — Watching it work

The demos, which are part of the deliverable rather than a development
artifact. Both viewers side by side drawing from one corpus; counts of
what has been drawn, by whom, how often; the moment a corpus runs dry
shown rather than described.

Issues: `400`–`4xx`.
