# Phase 2 Progress — Things That Roll, Fly, and Sail

**The goal:** the unit. One record for everything that can be shot, in three
domains from the first build, with infinite range bounded by sight, damage that
falls with distance and lands later, and health that comes back on a shared
timer. The command truck and the enforcer are the two units with rules of their
own, and both are here.

**Ends with:** two lines of tanks meeting across a dune field, one on a ridge and
one in a trough, and the ridge losing — because it was seen first.

| Issue | | Status |
| --- | --- | --- |
| 201 | A unit is one record | not started |
| 202 | The unit catalogue | not started |
| 203 | Three domains on one field | not started |
| 204 | Movement follows a pattern | not started |
| 205 | Nothing is out of range | not started |
| 206 | Damage is buffered, then applied | not started |
| 207 | Health comes back on a shared timer | not started |
| 208 | Death leaves bones | not started |
| 209 | The thread pool slices the tick | not started |
| 210 | The command truck moves and dies in one hit | not started |
| 211 | The enforcer walks forward and eats | not started |

**Blocking:** A3 (tracking or ballistic shells) sits under 205 and 206 and is the
one question here that changes the shape of the code rather than a number. It
should be worked through with a person before 206 is built.

**Carry into the work:** the catalogue's relations — hits-to-kill in tank shells,
the cost ratios — are what the tests assert; the magnitudes are the balance
ledger's business and are not in any document.

**Demo:** not yet built.
