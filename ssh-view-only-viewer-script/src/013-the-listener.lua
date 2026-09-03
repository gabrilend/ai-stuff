-- 013-the-listener.lua
--
-- Waits for packets and hands each one, unexamined, to whoever asked to
-- be told.  It knows nothing about what makes a packet good; that
-- judgement belongs to the arrangement.  Keeping the two apart means the
-- judging half can be tested without a network and this half can be
-- swapped for a different way of carrying packets without the judgement
-- changing at all.
--
-- Two ways of carrying are offered, chosen by name from a table rather
-- than by branching, so adding a third is adding an entry.
--
-- LuaJIT (5.1) syntax.  Needs LuaSocket for the udp carrier.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local listener = {}

-- The largest datagram we will read.  The arrangement refuses anything
-- over 256 bytes anyway; reading a little more means an oversized packet
-- is seen and refused with a reason, rather than being silently cut down
-- to a length that might accidentally parse.
listener.READ_SIZE = 1024

-- {{{ local function carry_by_udp()
-- Waits on a UDP port and calls back with each datagram.
--
-- UDP rather than TCP because a knock is one message with no
-- conversation after it: there is no handshake to complete, nothing to
-- acknowledge, and nothing for a stranger to learn from the fact that a
-- socket accepted them.  A wrong packet produces no reply at all, so
-- from outside, a machine that is listening and a machine that is not
-- look the same.
--
-- The timeout exists so the loop can come up for air and let the caller
-- sweep expired grants.  Without it, a machine that nobody knocks at
-- would never remove anything.
local function carry_by_udp(options, on_packet, should_continue)
    local socket = require("socket")

    local sock = assert(socket.udp())
    assert(sock:setsockname(options.address or "0.0.0.0", options.port))
    sock:settimeout(options.tick_seconds or 5)

    while should_continue() do
        local data, from_host = sock:receivefrom(listener.READ_SIZE)
        if data then
            on_packet(data, from_host)
        end
        -- A timeout is not an error here; it is the loop's heartbeat.
        -- Any other failure is left to surface rather than be swallowed.
    end

    sock:close()
end
-- }}}

-- {{{ local function carry_by_stdin()
-- Reads one packet per line from standard input.
--
-- This is how the doorman is tested and how it can be driven by
-- something else that already has the packets -- a capture, a different
-- transport, a person typing.  It exists so that "did the machine do the
-- right thing with this packet" can be asked without a network being
-- part of the question.
local function carry_by_stdin(options, on_packet, should_continue)
    for line in io.lines() do
        if not should_continue() then break end
        on_packet(line, "stdin")
    end
end
-- }}}

-- How a packet may arrive.  A table rather than a chain of tests: adding
-- a carrier is adding a row, and nothing else in the file changes.
listener.carriers = {
    udp   = carry_by_udp,
    stdin = carry_by_stdin,
}

-- {{{ function listener.listen()
-- Runs the named carrier until it is told to stop.
--
-- Refuses an unknown name rather than picking a default.  A doorman that
-- silently fell back to reading standard input when asked for a network
-- port would appear to be running and would never hear anybody.
function listener.listen(carrier_name, options, on_packet, should_continue)
    local carrier = listener.carriers[carrier_name]
    if not carrier then
        local known = {}
        for name in pairs(listener.carriers) do known[#known + 1] = name end
        table.sort(known)
        error("no such carrier: " .. tostring(carrier_name) ..
              " (known: " .. table.concat(known, ", ") .. ")")
    end

    if type(on_packet) ~= "function" then
        error("listen: on_packet must be a function")
    end

    should_continue = should_continue or function() return true end

    return carrier(options or {}, on_packet, should_continue)
end
-- }}}

return listener
