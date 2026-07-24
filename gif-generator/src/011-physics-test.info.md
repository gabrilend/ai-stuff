# 011-physics-test — proof for the integrator

Runnable directly (`luajit src/011-physics-test.lua [project-dir]`).
Proves: drag-only decay matches the arithmetic to the digit; no
forces means exactly linear drift; absurd drag rests instead of
vibrating; a same-lifetime cohort dies together on time; fade blazes
at birth, embers at the end, and only descends; a jittered swarm
replays exactly under one seed. Its own first run tripped the pool's
overflow wall by under-sizing — kept as a comment where it happened.
Exits nonzero on failure.
