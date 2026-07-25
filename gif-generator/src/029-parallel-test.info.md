# 029-parallel-test — proof for the many-hands pipeline

Runnable directly (`luajit src/029-parallel-test.lua [project-dir]`).
Renders the orbit reference three ways — sequential runner, one
worker, three workers — and demands all three gifs byte-identical,
with the same peak population and frame count; zero workers is
refused. Each render recompiles from disk (the reused-timeline carry
leak is explained in a comment). Exits nonzero on failure.
