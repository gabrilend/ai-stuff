# 017-test-blitter — info

Tests for `016-blitter.lua` on a throwaway project:
- a scripted series: good edits, a stale base, `kitten` over `cat`, and a
  conflict;
- one arrival of each kind it refuses, each moved aside with its reason
  logged and counted; a file still being written left alone;
- a skipped turn, a collision rule changed while it runs, a settings file
  that stops reading, and a merge mode not built yet;
- the stop file, and the goodbye receipt's every counter;
- the real program through `scripts/run-blitter`, taking an arrival and then
  stopped by a TERM signal with a goodbye.

It takes about five seconds, because the real program waits a second
between listings.

    luajit src/017-test-blitter.lua [--dir ROOT]
