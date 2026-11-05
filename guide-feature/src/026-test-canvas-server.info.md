# 026-test-canvas-server — info

Tests for `025-canvas-server.lua`. The real server runs through
`scripts/run-canvas-server`, on 127.0.0.1 and a free port only, beside a
blitter on a throwaway project. It is asked with curl and raw LuaSocket
connections:
- each route, byte for byte against the canvas files;
- numbers and queries that are not routes;
- two waiting requests answered by one new version, within half a second;
- a wait timing out with 204;
- a wait answered across a blitter restart;
- a waiter that hangs up;
- POST and HEAD (405), a line that is not a request, requests too large
  (413, also one far larger, which must not lose its answer to a reset),
  one too slow (408), and one connection too many (503);
- the log lines and the goodbye receipt, every counter;
- a second run where this machine's requests are not logged, serving the
  files the blitter left.

It takes about fifteen seconds.

    luajit src/026-test-canvas-server.lua [--dir ROOT]
