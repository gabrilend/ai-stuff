--[[
message_examples.lua - one example of every gameplay message (issue 803)

What this is: the values the message tests encode and check, shared by the
Lua round trip (tests/test_net_messages.lua) and the C unpacker's test
(tests/test_net_messages_c.lua), so both sides are checked against the
same messages. Floats are chosen to be exact in 32 bits.
]]

local messages = require("net.messages")

local examples = {
    order = { order_id = 7, given_tick = 900, kind = messages.order_kind.attack,
              target_x = 1024.5, target_y = -256.25, target_unit = 40,
              units = { { id = 12 }, { id = 13 }, { id = 4000000000 } } },
    heard = { tick = 905 },
    order_answer = { order_id = 7, accepted = 0, effect_tick = 906, refusal = messages.refusal.not_yours },
    unit_states = { tick = 900, units = {
        { id = 12, x = 1.5, y = 2.25, z = 0, vx = -3.5, vy = 0, vz = 0.125, facing = 1.5, anim = 3, anim_phase = 0.75, radius = 0.5, team = 0 },
        { id = 13, x = -8, y = 16, z = 0.5, vx = 0, vy = 0, vz = 0, facing = 0, anim = 0, anim_phase = 0, radius = 0.75, team = 1 },
    } },
    events = { tick = 903, events = {
        { kind = messages.event_kind.death, tick = 902, unit = 40, other = 12 },
    } },
    waiting = { tick = 1000, paused = 1, silent = {
        { player = 3, silent_ms = 2500, countdown_ms = 27500 },
    } },
    tolerance = { ms = 2000 },
    tolerances = { in_force_ms = 500, players = { { player = 0, ms = 2000 }, { player = 1, ms = 500 } } },
    drop_vote = { player = 3 },
    votes = { needed = 2, silent = { { player = 3, votes = 1 } } },
    paths = { tick = 900, stopped = { { id = 4 } }, points = { { id = 12, x = 1.5, y = 2.5 }, { id = 12, x = 2.5, y = 2.5 } } },
}

return examples
