--[[
renderer_link.lua - the renderer's side of the connection, run by the renderer's receiving thread (issue 804)

What this is: the Lua a C renderer runs on its receiving thread. It starts
the server on a thread of its own (net/hosted.lua) with the crossing game,
and plays two players into it: this player (0), whose messages it hands
to C, and a stand-in second player (1) who only keeps saying "heard", so
the waiting dialog has someone to wait for when that stand-in is told to
go silent.

C calls, all from the one receiving thread:
  link.start(dir)            -> the map: rows (text), cell, unit_radius
  link.poll()                -> this player's messages due now (a list of
                                byte strings); sends both players' heard
                                beats when one is due (every 16 ms)
  link.disturb(delay_ms, jitter_ms, loss)
                             this player's connection, both ways, live
  link.silence_stand_in(on)  the stand-in stops (or resumes) saying heard
  link.tolerance(ms)         this player's slider
  link.vote(player)          this player's drop vote
  link.stop()                -> ticks the server ran
]]

local link = {}

local hosted, messages, clock
local h, me, stand_in
local newest = { [0] = 0, [1] = 0 }   -- each player's newest tick received
local next_beat = 0
local stand_in_silent = false

-- {{{ function link.start(dir)
function link.start(dir)
    package.path = dir .. "/src/?.lua;" .. dir .. "/src/?/init.lua;" .. package.path
    package.cpath = "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so;" .. package.cpath
    hosted = require("net.hosted")
    messages = require("net.messages")
    clock = require("net.clock")
    h = hosted.start({ dir = dir, players = 2, sim = "net.crossing_sim", sim_config = {} })
    me, stand_in = h:player(0), h:player(1)
    next_beat = clock.now_ms()
    local map = require("net.arenas.crossing")
    return map.rows, map.cell, map.unit_radius
end
-- }}}

-- {{{ local function newest_tick(p, bytes)
-- Notes the tick of a unit_states message (type byte 4), for the beats.
local function newest_tick(p, bytes)
    if bytes:byte(1) == 4 then
        local tick = bytes:byte(2) + bytes:byte(3) * 256 + bytes:byte(4) * 65536 + bytes:byte(5) * 16777216
        if tick > newest[p] then newest[p] = tick end
    end
end
-- }}}

-- {{{ function link.poll()
function link.poll()
    local now = clock.now_ms()
    local mine = me.take()
    for _, bytes in ipairs(mine) do newest_tick(0, bytes) end
    for _, bytes in ipairs(stand_in.take()) do newest_tick(1, bytes) end
    if now >= next_beat then
        me:send(messages.encode("heard", { tick = newest[0] }))
        -- Two paths: the stand-in is talking -> it beats too; silenced -> it
        -- says nothing, and the server will pause everyone once the silence
        -- passes the strictest slider
        if not stand_in_silent then stand_in:send(messages.encode("heard", { tick = newest[1] })) end
        -- catch up without a burst if the thread was held up
        next_beat = math.max(next_beat + 16, now)
    end
    return mine
end
-- }}}

-- {{{ function link.disturb(delay_ms, jitter_ms, loss)
function link.disturb(delay_ms, jitter_ms, loss)
    for _, end_ in ipairs({ me.link, me.inbox }) do
        end_.delay_ms, end_.jitter_ms, end_.loss = delay_ms, jitter_ms, loss
    end
end
-- }}}

-- {{{ function link.silence_stand_in(on)
function link.silence_stand_in(on)
    stand_in_silent = on
end
-- }}}

-- {{{ function link.tolerance(ms)
function link.tolerance(ms)
    me:send(messages.encode("tolerance", { ms = ms }))
end
-- }}}

-- {{{ function link.vote(player)
function link.vote(player)
    me:send(messages.encode("drop_vote", { player = player }))
end
-- }}}

-- {{{ function link.stop()
function link.stop()
    return h:stop().ticks
end
-- }}}

return link
