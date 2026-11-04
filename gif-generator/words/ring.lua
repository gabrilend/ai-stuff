-- words/ring.lua — a whole circle traced once, as two half-arcs in turn.
-- Written by hand as the first worked example of a pattern word (604a).

return {
    word = "ring",
    aliases = { "rings", "circle", "circles" },
    kind = "pattern",
    meaning = "A whole circle traced once around, clockwise from twelve "
        .. "o'clock, over the time given: the first half then the second.",
    fields = {
        center = "{x, y} in pixels, where the ring is centred",
        radius = "the ring's radius in pixels",
    },
    -- {{{ expand()
    -- The score's arc cannot go all the way round in one stroke (from and
    -- to would be the same hour), so the ring is two arcs, each taking half
    -- the time; the second starts where the first ends. Times stay in
    -- tenths: an odd number of tenths gives the first half the extra one.
    expand = function(call)
        local tenths = math.floor(call.lasts * 10 + 0.5)
        local first = math.ceil(tenths / 2) / 10
        local second = tenths / 10 - first
        local base = {
            color = call.color, fade = call.fade or "hold",
            ease = call.ease, emit = call.emit,
        }
        local function half(at, lasts, from, to)
            local s = {}
            for k, v in pairs(base) do s[k] = v end
            s.at, s.lasts = at, lasts
            s.shape = arc{ center = call.center, radius = call.radius,
                           from = from, to = to, turn = "clockwise" }
            return s
        end
        return {
            half(call.at, first, "12 o'clock", "6 o'clock"),
            half(math.floor((call.at + first) * 10 + 0.5) / 10, second,
                 "6 o'clock", "12 o'clock"),
        }
    end,
    -- }}}
    example = 'pattern{ name = "ring", at = 0.0, lasts = 2.0, color = "ice", '
        .. 'center = {128, 128}, radius = 70 }',
}
