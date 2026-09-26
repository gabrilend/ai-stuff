#!/usr/bin/env luajit
-- units-gen.lua - writes the host loop's map (issue 515b)
--
-- In plain terms: the first render frame as the ceramic engine reads it.
-- `advance` takes the host's tick (argument 0) and fans the frame's clock
-- out to eight `move` lanes; each lane also takes the host's request for
-- that lane (arguments 1..8) and answers with its units (results 0..7).
--
-- Usage: luajit units-gen.lua > units.map

local LANES = 8
local out = {}
local function w(s) out[#out + 1] = s end
w("# The host loop's first frame (issue 515b), written by units-gen.lua.")
w("")
w("station advance (units-boxes.c:advance)")
w("  in 0 - 0$")
for l = 0, LANES - 1 do w(string.format("  out 0 - move%d.1", l)) end
for l = 0, LANES - 1 do
    w("")
    w(string.format("station move%d (units-boxes.c:move)", l))
    w(string.format("  in 0 - %d$", 1 + l))
    w("  in 1 - advance.0")
    w(string.format("  out 0 - %d$", l))
end
print(table.concat(out, "\n"))
