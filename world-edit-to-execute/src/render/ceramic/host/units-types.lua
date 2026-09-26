#!/usr/bin/env luajit
-- units-types.lua - writes a lane's answer as a value type the engine accepts (issue 515b)
--
-- In plain terms: a lane of the host loop's map answers with every one of
-- its units' places and colours. The ceramic engine's value types can't
-- hold arrays of numbers, so the answer is written as one named field per
-- unit (u0 .. u255, each a `unit`), which this prints, and run-host.sh
-- splices into the box file at the marker. The code reads the fields as an
-- array: a struct whose fields share one type has no gaps between them.
--
-- Usage: luajit units-types.lua > types.c   (units per lane below)

local PER_LANE = 256

print("/* One lane's answer: " .. PER_LANE .. " units, " .. PER_LANE * 16 .. " bytes. */")
print("typedef struct {")
for i = 0, PER_LANE - 1 do print(string.format("    unit u%d;", i)) end
print("} lane_units;")
