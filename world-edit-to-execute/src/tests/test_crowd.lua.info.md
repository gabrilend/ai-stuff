# test_crowd.lua

Small scenes drawn as text, ticked while checking no two units overlap at
any tick (issue 405f): around a standing unit; head-on in a corridor;
past a unit that stops ahead; an unreachable goal (as close as it can
get); boxed in (gives up after 5 s); the goal taken (a free cell beside
it); two armies of 40 swapping sides through a 12-cell gap (at least 80%
arrive; it prints the time per tick and the counts).

- **Usage:** `luajit src/tests/test_crowd.lua [DIR]`; exits 1 on a failure.
