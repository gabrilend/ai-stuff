--[[
link.lua - one direction of a connection, which can be made to behave like a bad network (issue 803)

What this is: how messages travel between the server and a player when
the server runs inside the client. Each direction is a queue between two
threads (an effil channel). Messages are strings of bytes, so nothing is
shared between the threads.

The disturbance: a link can hold each message back before it is handed
over, as a network would. The sender decides each message's fate when it
sends it:
  delay_ms      every message arrives this much later
  jitter_ms     plus a random extra, 0 up to this much (so messages can
                overtake each other, as on a real network)
  loss          the chance (0 to 1) that a message never arrives
  silent        a list of {from_ms, to_ms} spans, counted from the link's
                start, in which nothing sent arrives at all (a player whose
                connection has dropped)
  seed          for the random draws, so a disturbed run can be repeated
The receiver keeps messages that have come through the queue but aren't
due yet, and hands them over when their time comes.

A receiver can be disturbed too (its own delay_ms, jitter_ms, loss and
seed, which may be changed while it runs): the fate is then decided when a
message comes out of the queue. That's how a renderer turns a bad network
on and off live, from its own thread, without reaching into the server's.

Every time here is clock.now_ms(), which both threads read alike.
]]

local clock = require("net.clock")

local link = {}
link.__index = link

-- {{{ function link.sender(channel, disturbance)
-- The sending end. `disturbance` may be nil: then messages arrive as soon
-- as they are taken.
function link.sender(channel, disturbance)
    local d = disturbance or {}
    local self = setmetatable({
        channel = channel,
        delay_ms = d.delay_ms or 0, jitter_ms = d.jitter_ms or 0, loss = d.loss or 0,
        silent = d.silent or {}, start_ms = d.start_ms or clock.now_ms(),
        sent = 0, lost = 0,
    }, link)
    -- each sender draws from its own seeded sequence
    self.random = d.seed and link.random_from(d.seed) or math.random
    return self
end
-- }}}

-- {{{ function link.random_from(seed)
-- A small repeatable random sequence (numbers from 0 up to 1), separate
-- from math.random so two links don't disturb each other's draws.
function link.random_from(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end
-- }}}

-- {{{ function link:send(bytes)
-- Decides the message's fate and puts it in the queue with the moment it
-- is due. Two paths: lost (to silence or chance) -> never queued;
-- otherwise -> queued with its due time.
function link:send(bytes)
    local now = clock.now_ms()
    self.sent = self.sent + 1
    local since = now - self.start_ms
    for _, span in ipairs(self.silent) do
        if since >= span[1] and since < span[2] then self.lost = self.lost + 1; return end
    end
    if self.loss > 0 and self.random() < self.loss then self.lost = self.lost + 1; return end
    local due = now + self.delay_ms + (self.jitter_ms > 0 and self.random() * self.jitter_ms or 0)
    self.channel:push(due, bytes)
end
-- }}}

local receiver = {}
receiver.__index = receiver

-- {{{ function link.receiver(channel, disturbance)
-- The receiving end. `disturbance` (optional): delay_ms, jitter_ms, loss,
-- seed; the fields stay changeable on the receiver.
function link.receiver(channel, disturbance)
    local d = disturbance or {}
    return setmetatable({
        channel = channel, waiting = {},
        delay_ms = d.delay_ms or 0, jitter_ms = d.jitter_ms or 0, loss = d.loss or 0,
        random = d.seed and link.random_from(d.seed) or math.random,
        received = 0, lost = 0,
    }, receiver)
end
-- }}}

-- {{{ function receiver:take(now_ms)
-- Every message due by `now_ms`, earliest due first. Messages come through
-- the queue in the order they were sent, but jitter can make a later one
-- due sooner, so they wait here sorted by due time.
function receiver:take(now_ms)
    while true do
        local due, bytes = self.channel:pop(0)
        if due == nil then break end
        self.received = self.received + 1
        -- Two paths: lost on the way in -> dropped; otherwise -> held for
        -- this end's own delay and jitter as well as the sender's
        if self.loss > 0 and self.random() < self.loss then
            self.lost = self.lost + 1
        else
            local held = now_ms + self.delay_ms + (self.jitter_ms > 0 and self.random() * self.jitter_ms or 0)
            self.waiting[#self.waiting + 1] = { due = math.max(due, held), bytes = bytes }
        end
    end
    table.sort(self.waiting, function(a, b) return a.due < b.due end)
    local ready, kept = {}, {}
    for _, m in ipairs(self.waiting) do
        if m.due <= now_ms then ready[#ready + 1] = m.bytes else kept[#kept + 1] = m end
    end
    self.waiting = kept
    return ready
end
-- }}}

return link
