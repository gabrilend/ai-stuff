# 001-canvas-test — proof for the light buffer

Runnable directly (`luajit src/001-canvas-test.lua [project-dir]`).
Asserts the rendering datapath's promises: untouched pixels map to
exact black, deposits sum, extreme energy never clips a byte, more
light never reads darker (by luminance), dim hues keep their color
while blazing ones bleach white, and the walls refuse out-of-bounds
deposits and nonsense sizes. Exits nonzero on any failure.
