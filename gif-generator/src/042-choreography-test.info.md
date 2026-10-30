# 042-choreography-test — proof for the stage manager

Asks `035-choreography.lua` directly, with no pixels, whether every scene in
`input/shapes/` (and the test scenes in `tests/shape-films/`) loops without a
seam, whether each word of the scene vocabulary does what it says, and
whether broken scenes are refused.

CLI: `luajit src/042-choreography-test.lua DIR`. Run with the rest of the
shape films' checks by `./test-shape-films`.
