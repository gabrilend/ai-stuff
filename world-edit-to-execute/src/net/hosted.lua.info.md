# hosted.lua

Runs the server on a thread of its own inside the client (issue 803):
offline play, and every test of the messages. Needs effil
(`/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/` on
`package.cpath`).

- **`hosted.start(options) -> handle`:** `options.dir` (the project, where
  the thread loads modules), `players`, `sim` (a module name) and
  `sim_config`, and optional per-player disturbances `to_server[p]` and
  `to_client[p]` (as in `link.lua`).
- **`handle:player(p) -> end`:** `end:send(bytes)` toward the server;
  `end:take() -> list of bytes` due now.
- **`handle:stop() -> report`:** stops the thread; `report.ticks`,
  `report.refused` (count), `report.lost` (messages the server's links
  lost), `report.why` (every refusal's reason, a line each). Raises the
  thread's error if it failed.
