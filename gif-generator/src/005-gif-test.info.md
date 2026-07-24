# 005-gif-test — proof for the encoder

Runnable directly (`luajit src/005-gif-test.lua [project-dir]`).
Contains the deliberately dumb LZW decoder (tests only, never the
pipeline) and a block-walker that rulers the file structure. Proves:
patterned frames, noise (which forces dictionary resets), and a
full-size gradient all round-trip byte-for-byte; the loop extension,
delays, dimensions, and trailer survive; compression happens; no
frames and fractional delays are refused. Exits nonzero on failure.
