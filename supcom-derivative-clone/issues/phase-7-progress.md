# Phase 7 Progress — Other Players

**The goal:** lockstep. Every machine runs the whole match, only intent crosses
the wire, and a disagreement halts with its tick named. On a computer the wire is
a local network; on the handheld it is the sibling project's transport, and that
issue is a blueprint whose numbers are pending.

**Ends with:** two people, on two computers in one room, playing a match to the
end, and a third machine joining late and catching up from the command log.

| Issue | | Status |
| --- | --- | --- |
| 701 | Lockstep, and why | not started |
| 702 | Commands are scheduled for a later tick | not started |
| 703 | Reaching a peer from a computer | not started |
| 704 | Finding each other | not started |
| 705 | A desync is named, not hidden | not started |
| 706 | Dropping and rejoining | not started |
| 707 | Reaching a peer from the handheld | not started |
| 708 | Two people play a match | not started |

**Blocking:** F2 (doubles across targets) is awaiting evidence and is the one
thing that could change the shape of the world arrays; it is answered by running
the same match on both targets, which needs phase 8's build. F4 (the handheld's
radio) is pending the sibling project and blocks 707 and the handheld capstone,
not the computer capstone.

**Carry into the work:** the command door from 108 already stamps every command
with a tick; lockstep adds a delay and a refusal, and nothing else changes in
the simulation.

**Demo:** not yet built.
