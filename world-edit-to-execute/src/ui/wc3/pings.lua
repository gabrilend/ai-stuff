--[[
Minimap Pings (Issue 507f)

What a ping looks like at a moment, for whatever draws it (the minimap and
the world view). Nothing here draws: it gathers the pings showing now and
says, for each, where it is, its colour, how see-through it is and how far
its rings have spread, so the drawing side only has to draw circles.

Two kinds of ping come in:
  - a trigger's (the PingMinimap natives), kept on the JASS VM as V.pings,
    each { x, y, at, ends, r, g, b, flashy } in the VM's seconds;
  - a player's (Alt-click, the ping and pinged messages of issue 803),
    kept here with pings.heard(list, pinged, now) from each pinged message.

Times are seconds. A list is a plain Lua table of pings.
]]

local pings = {}

pings.PLAYER_SECONDS = 3     -- how long a player's ping shows
pings.FADE_SECONDS = 0.5     -- a ping fades out over its last half second
pings.RING_SECONDS = 1       -- an expanding ring every second
pings.FLASHY_RING_SECONDS = 0.5
pings.PLAYER_COLOUR = { 255, 255, 0 }   -- yellow, as the January design and the game have it
pings.KEPT = 16              -- the most player pings kept; the oldest goes first

-- {{{ function pings.heard(list, pinged, now)
-- Keeps a player's ping from a decoded pinged message. Returns the ping.
function pings.heard(list, pinged, now)
    local c = pings.PLAYER_COLOUR
    local p = { x = pinged.x, y = pinged.y, at = now, ends = now + pings.PLAYER_SECONDS,
                r = c[1], g = c[2], b = c[3], flashy = false, player = pinged.player }
    list[#list + 1] = p
    if #list > pings.KEPT then table.remove(list, 1) end
    return p
end
-- }}}

-- {{{ function pings.forget(list, now)
-- Drops the pings whose time is up, in place. Returns the list.
function pings.forget(list, now)
    local w = 0
    for i = 1, #list do
        if list[i].ends > now then
            w = w + 1
            list[w] = list[i]
        end
    end
    for i = #list, w + 1, -1 do list[i] = nil end
    return list
end
-- }}}

-- {{{ function pings.is_attack(p)
-- Pure red, not flashy: the game's attack ping (Blizzard.j's style 2).
function pings.is_attack(p)
    return p.r == 255 and p.g == 0 and p.b == 0 and not p.flashy
end
-- }}}

-- {{{ function pings.look(p, now)
-- How a ping looks at now: nil once its time is up (or before it starts),
-- else { x, y, r, g, b, alpha (0-255), ring (0-1, how far the ring has
-- spread), attack, player }. A ping is solid until its last FADE_SECONDS,
-- then fades to nothing; a flashy one's rings come twice as fast.
function pings.look(p, now)
    if now < p.at or now >= p.ends then return nil end
    local left = p.ends - now
    local alpha = 255
    if left < pings.FADE_SECONDS then alpha = math.floor(255 * left / pings.FADE_SECONDS + 0.5) end
    local every = p.flashy and pings.FLASHY_RING_SECONDS or pings.RING_SECONDS
    local ring = ((now - p.at) % every) / every
    return { x = p.x, y = p.y, r = p.r, g = p.g, b = p.b, alpha = alpha, ring = ring,
             attack = pings.is_attack(p), player = p.player }
end
-- }}}

-- {{{ function pings.showing(now, ...)
-- Every ping showing at now, from any number of lists (V.pings, the
-- player pings kept by heard), oldest first.
function pings.showing(now, ...)
    local out = {}
    for i = 1, select("#", ...) do
        local list = select(i, ...)
        for _, p in ipairs(list or {}) do
            local l = pings.look(p, now)
            if l then
                l.at = p.at
                out[#out + 1] = l
            end
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end
-- }}}

return pings
