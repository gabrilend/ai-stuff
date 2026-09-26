# crowd-common.h

What every crowd runner shares (issue 515k), header only:
`scene_load(path, &scene) -> crowd` (crowd-scene.lua's format);
`crossing_start` / `crossing_step` (the armies across and back, as the Lua
runner does); `now_us`; `pause_a_moment`; `report(...)` (the one-line
result with `checksum`, FNV-1a over every position's bits); the timeline
(`timeline_open`, `timeline_tick`, `timeline_on`, `timeline_add`,
`timeline_close`: tick, worker, chunk, start and end in microseconds).
