# 007-pool-test — proof for the pool

Runnable directly (`luajit src/007-pool-test.lua [project-dir]`).
Proves: births fill the prefix in order; swap-with-last moves the
tail into the hole and touches nothing else; the overflow wall names
its asker; killing beyond the prefix refuses; twenty thousand
deterministic churns never bend the count; sizing covers steady state
without ballooning, and overlapping demands stack while disjoint ones
don't. Two of its own early bugs are commented where they were fixed
(float32 equality, dashes in Lua patterns). Exits nonzero on failure.
