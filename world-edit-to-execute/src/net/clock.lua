--[[
clock.lua - milliseconds on a clock every thread agrees on (issue 803)

What this is: the time the server and its clients measure silence, delays
and ticks by. It reads the operating system's monotonic clock (which never
jumps when the wall clock is set), so two threads asking at the same moment
get the same answer. Lua's own os.clock() counts processor time used by
this program instead, which runs faster than real time when several
threads are busy.
]]

local ffi = require("ffi")

ffi.cdef[[
typedef struct { long tv_sec; long tv_nsec; } net_clock_timespec;
int clock_gettime(int clock_id, net_clock_timespec *tp);
]]

local CLOCK_MONOTONIC = 1
local now = ffi.new("net_clock_timespec")

local clock = {}

-- {{{ function clock.now_ms()
-- Milliseconds since some fixed moment (the machine's start), with
-- fractions.
function clock.now_ms()
    ffi.C.clock_gettime(CLOCK_MONOTONIC, now)
    return tonumber(now.tv_sec) * 1000 + tonumber(now.tv_nsec) / 1e6
end
-- }}}

return clock
