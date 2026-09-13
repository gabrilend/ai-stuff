# Phase 1 Progress — The Dunes and the Clock

**The goal:** a world that does nothing, correctly. A field of dunes raised by a
tool, a way to ask whether one point sees another, a heartbeat that is a table,
one door for player intent, a way to get pictures out, and the reproducibility
guarantee every later phase and the whole network model lean on. No units, no
fighting.

**Ends with:** a headless runner that raises a field, advances an empty world ten
thousand ticks, prints the same hash twice, and a terminal viewer that draws the
dunes and the water line as text — so that from phase 2 onward nobody works
blind.

| Issue | | Status |
| --- | --- | --- |
| 101 | The project is built by its tools | built |
| 102 | The dunes are raised by a tool | not started |
| 103 | Sightlines are read off the dunes | not started |
| 104 | The world is flat arrays | not started |
| 105 | The tick is a dispatch table | not started |
| 106 | A periodic effect is a pair of integers | not started |
| 107 | Randomness comes from named streams | not started |
| 108 | Commands enter through one door | not started |
| 109 | Snapshots, hashes, and replays | not started |
| 110 | The headless runner | not started |
| 111 | A terminal viewer, so we are not blind | not started |
| 112 | Territory is painted on cells | not started |
| 113 | Every mechanic has a test | not started |

**Blocking:** nothing outside the phase. B4 (ticks per second) and B5 (field size
and shell speed) are working rulings the phase can proceed on; they are numbers
in the catalogue and change nothing structural.

**Carry into the work:** the tests in `tests/` were written before any of this and
name the stems each issue's source file must take. Read
`docs/014-the-tests-come-first.md` before claiming a file.

**Demo:** not yet built.
