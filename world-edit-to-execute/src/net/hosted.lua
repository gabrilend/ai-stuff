--[[
hosted.lua - runs the server on a thread of its own inside the client (issue 803)

What this is: offline play, and every test of the messages. The server
(server.lua, with a game plugged in) runs on its own thread; each player
has two queues to it, one each way, and the bytes that cross them are the
same bytes a network would carry. Either direction of either player's
connection can be disturbed (link.lua): delayed, jittered, lossy, or silent
for a while.

The server's thread loops: take every message that is due, hand each to
the server, let the server catch up to the clock, rest a millisecond. It
stops when asked, and reports what it did.

Usage:
  local hosted = require("net.hosted")
  local h = hosted.start({
      dir = DIR, players = 2,
      sim = "net.circling_sim", sim_config = { units = 64, players = 2 },
      to_server = { [1] = { delay_ms = 40 } },       -- per player, optional
      to_client = { [0] = { loss = 0.1, seed = 7 } },
  })
  local me = h:player(0)     -- me:send(bytes), me:take() -> list of bytes
  ...
  local report = h:stop()    -- ticks, refused, lost
]]

local effil = require("effil")
local clock = require("net.clock")
local link = require("net.link")

local hosted = {}
hosted.__index = hosted

-- {{{ local function server_thread(options, up, down, stop, start_ms)
-- The server's thread. Everything it needs arrives as arguments (effil
-- copies plain tables into shared ones, which effil.dump turns back).
local function server_thread(options, up, down, stop, start_ms)
    local effil = require("effil")
    package.path = options.dir .. "/src/?.lua;" .. options.dir .. "/src/?/init.lua;" .. package.path
    local clock = require("net.clock")
    local link = require("net.link")
    local server = require("net.server")
    local o = effil.dump(options)

    local sim = require(o.sim).new(o.sim_config)
    local receivers, senders = {}, {}
    for p = 0, o.players - 1 do
        receivers[p] = link.receiver(up[p])
        local d = o.to_client and o.to_client[p] or {}
        d.start_ms = start_ms
        senders[p] = link.sender(down[p], d)
    end
    local s = server.new(sim, o.players, function(p, bytes) senders[p]:send(bytes) end, clock.now_ms())

    while not stop.now do
        local now = clock.now_ms()
        for p = 0, o.players - 1 do
            for _, bytes in ipairs(receivers[p]:take(now)) do s:receive(p, bytes, now) end
        end
        s:step(now)
        clock.sleep_ms(1)
    end

    local lost = 0
    for p = 0, o.players - 1 do lost = lost + senders[p].lost end
    local refused = {}
    for i, r in ipairs(s.refused) do refused[i] = r.why end
    return s.tick, #s.refused, lost, table.concat(refused, "\n")
end
-- }}}

-- {{{ function hosted.start(options)
-- Starts the server's thread. `options.dir` is the project's directory
-- (the thread loads its modules from there).
function hosted.start(options)
    local h = setmetatable({ options = options, up = {}, down = {}, start_ms = clock.now_ms() }, hosted)
    for p = 0, options.players - 1 do
        h.up[p] = effil.channel()
        h.down[p] = effil.channel()
    end
    h.stop_flag = effil.table({ now = false })
    h.thread = effil.thread(server_thread)(options, h.up, h.down, h.stop_flag, h.start_ms)
    return h
end
-- }}}

-- {{{ function hosted:player(p)
-- Player p's end: send(bytes) to the server, take() the messages due now.
-- The disturbance toward the server (options.to_server[p]) is applied here.
function hosted:player(p)
    local d = self.options.to_server and self.options.to_server[p] or {}
    d.start_ms = self.start_ms
    local out = link.sender(self.up[p], d)
    local inbox = link.receiver(self.down[p])
    return {
        link = out, inbox = inbox,   -- both ends, whose disturbances may be changed live
        send = function(_, bytes) out:send(bytes) end,
        take = function() return inbox:take(clock.now_ms()) end,
    }
end
-- }}}

-- {{{ function hosted:stop()
-- Stops the server's thread. Returns { ticks, refused, lost, why } -- `why`
-- is every refusal's reason, one a line. A thread that failed raises its
-- error here.
function hosted:stop()
    self.stop_flag.now = true
    local status, err = self.thread:wait()
    if status ~= "completed" then error("the server's thread ended " .. tostring(status) .. ": " .. tostring(err), 0) end
    local ticks, refused, lost, why = self.thread:get()
    return { ticks = ticks, refused = refused, lost = lost, why = why }
end
-- }}}

return hosted
