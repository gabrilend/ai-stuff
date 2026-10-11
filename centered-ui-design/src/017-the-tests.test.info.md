<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 017-the-tests.test

Every check that needs no window, run with plain LuaJIT by `scripts/run-tests` (which builds the ceramic library first): settings, camera, fold, records, move box, the C boxes inline through FFI (motion against the Lua twin; chunk order changing nothing, byte for byte; claims; carrying; delivery into the right section), seeding, frame cap, spheroid, body plan, arch. Prints PASS/FAIL per check; exits non-zero on any failure.
