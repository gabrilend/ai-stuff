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
int nanosleep(const net_clock_timespec *req, net_clock_timespec *rem);
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

-- {{{ function clock.sleep_ms(ms)
-- Rests this thread for `ms` milliseconds (fractions allowed), through the
-- operating system. effil.sleep(1, "ms") was used first and doesn't rest
-- at all (a hundred calls took 0.18 ms), so the server's thread spun a
-- whole core flat out and the machine's fans were loud.
local rest = ffi.new("net_clock_timespec")
function clock.sleep_ms(ms)
    rest.tv_sec = math.floor(ms / 1000)
    rest.tv_nsec = math.floor((ms % 1000) * 1e6)
    ffi.C.nanosleep(rest, nil)
end
-- }}}

return clock
