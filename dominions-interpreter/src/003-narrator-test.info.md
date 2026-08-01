# 003-narrator-test.lua

Proves the narrator. Exposes `run(check)`; needs no Dominions folder.

The case worth having is the last one: a worry raised without a reason fails at
the call site, rather than writing an empty string into a file somebody reads
later and learns nothing from.
