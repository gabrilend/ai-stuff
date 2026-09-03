# Table of contents

The goal is one script: send a packet, be given view-only SSH
credentials, look around. Everything numbered below reads in that order.

```
notes/
    vision                      the first sitting: a door that opens on a
                                stranger's name, and grants only watching
    vision-2                    the second: delete meaning "next please"
    blockers.md                 things outside this project, and whether
                                they actually stop us

docs/
    000-what-this-project-is.md the goal, its three parts, and where the
                                risk actually sits
    001-the-arrangement.md      datapath: what a packet is, and how a
                                machine tells a real one from a guess
    002-the-grant.md            datapath: making a credential, and
                                making sure it does not outlive its visit
    003-the-room.md             datapath: what view-only is made of
                                (NOT BUILT YET)
    004-the-refill-loop.md      datapath: r-mail delivery -- an example
    005-roadmap.md              phases, and what builds on what
    008-the-draw.md             datapath: choosing a file at random
    table-of-contents.md        this file

src/
    006-the-arrangement.lua     is this packet genuine, and who sent it
    007-the-grant.lua           plans an account into and out of being
    008-the-draw.lua            picks a file, for the example
    009-test-the-arrangement.lua   49 tests
    010-test-the-grant.lua         33 tests, none of which touch an account
    011-test-the-draw.lua          22 tests
    012-run-tests.sh            runs all of them
    013-the-listener.lua        how a packet arrives (udp, or stdin)
    014-the-doorman.lua         the program that waits by the door
    015-knock.lua               the other end: asks, and derives the
                                password rather than awaiting it

input/
    secret                      the shared secret; mode 600 or the
                                doorman refuses to start

issues/
    100-the-arrangement.md      phase 1
    200-the-grant.md            phase 2
    400-the-random-draw.md      phase 4, the example
    phase-N-progress.md         where each phase stands, and what it taught
    completed/                  closed issues, kept as the blueprint
```

Numbering counts across all directories, tracked in
`.file-index-counter`. Phases and their issue ranges are in
[the roadmap](005-roadmap.md): `1xx` the arrangement, `2xx` the grant,
`3xx` the room, `4xx` the example, `5xx` demos.

The source numbering has one wrinkle worth knowing: the tests and their
runner (009–012) sit between the modules they test and the wiring that
uses them (013–015). Reading 006, 007, 013, 014, 015 in that order gives
the whole path a packet takes.
