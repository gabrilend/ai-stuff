#!/usr/bin/env luajit
-- frame-gen.lua - writes the fabricated frame as a ceramic map (issue 515h)
--
-- In plain terms: the frame's shape, drawn as the engine reads it. One
-- simulation step fans out to four fog-of-war stations (each told its
-- player by a constant) and to eight pose lanes; each pose lane waits for
-- both the simulation's answer and the host's request for that lane, and
-- hands its answer straight to its own culling station; pathfinding and
-- background decoding stand on their own. Nothing says "wait for the
-- previous stage": each station runs the moment its own inputs arrive.
--
-- Doors (marked ports), which frame-host.c relies on:
--   arguments  0 the tick; 1..8 the pose lanes' requests; 9 pathfinding
--              requests; 10 background decodes
--   results    0..3 fog, one per player; 4..11 culling, one per lane;
--              12 pathfinding answers; 13 decoded answers
--
-- Usage: luajit frame-gen.lua > frame.map

local PLAYERS, LANES = 4, 8
local out = {}
local function w(s) out[#out + 1] = s end

w("# The fabricated frame (issue 515h), written by frame-gen.lua.")
w("")
w("station sim (frame-boxes.c:simulate)")
w("  in 0 - 0$")
for p = 0, PLAYERS - 1 do w(string.format("  out 0 - fog%d.0", p)) end
for l = 0, LANES - 1 do w(string.format("  out 0 - pose%d.1", l)) end
w("")
for p = 0, PLAYERS - 1 do
    w(string.format("station fog%d (frame-boxes.c:fog)", p))
    w("  in 0 - sim.0")
    w(string.format("  in 1 = %d", p))
    w(string.format("  out 0 - %d$", p))
    w("")
end
for l = 0, LANES - 1 do
    w(string.format("station pose%d (frame-boxes.c:pose_lane)", l))
    w(string.format("  in 0 - %d$", 1 + l))
    w("  in 1 - sim.0")
    w(string.format("  out 0 - cull%d.0", l))
    w("")
    w(string.format("station cull%d (frame-boxes.c:cull)", l))
    w(string.format("  in 0 - pose%d.0", l))
    w(string.format("  out 0 - %d$", PLAYERS + l))
    w("")
end
w("station paths (frame-boxes.c:pathfind)")
w(string.format("  in 0 - %d$", 1 + LANES))
w(string.format("  out 0 - %d$", PLAYERS + LANES))
w("")
w("station decodes (frame-boxes.c:decode)")
w(string.format("  in 0 - %d$", 2 + LANES))
w(string.format("  out 0 - %d$", PLAYERS + LANES + 1))
print(table.concat(out, "\n"))
