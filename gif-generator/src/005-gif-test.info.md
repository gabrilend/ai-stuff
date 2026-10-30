# 005-gif-test — proof for the encoder

Runnable directly (`luajit src/005-gif-test.lua [project-dir]`).
Reads what the encoder wrote with the studio's one reader
(`040-gif-decode.lua`, which shares no code with the encoder), asking it
for every frame's raw indices and the file's structure, and refuses
anything the encoder never writes (an offset frame, a local table, an odd
code size, a short stream). Proves: patterned frames, noise (which forces
dictionary resets), and a full-size gradient all round-trip byte-for-byte;
the loop extension, delays, dimensions, and trailer survive; compression
happens; no frames and fractional delays are refused. Exits nonzero on
failure. Until 701b it carried a private decoder of its own.
