-- 002-palette.lua — the glow palette and the indexer.
--
-- What this is, generally: GIF allows 256 colors, and we spend them
-- on purpose instead of asking a quantizer to guess. Index 0 is the
-- untouched black background. Each hue a score declares gets a ramp
-- from near-black through vivid toward white, with more steps in the
-- dark half where glow falloffs would otherwise band. A shared gray
-- ramp near the top catches white-hot cores (and any desaturated
-- stragglers). Mapping a tone-mapped pixel to its index is
-- arithmetic — hue picks the ramp, brightness picks the step — never
-- a search over all 256 candidates.
--
-- Data-format notes worth knowing more than once:
--   * palette bytes are 256 entries x 3 bytes (r,g,b), the exact
--     block the gif encoder embeds as the global color table.
--   * ramp brightness is gamma-spaced: entry j of an n-step ramp has
--     brightness (j/(n-1))^RAMP_GAMMA, so low entries crowd the dark
--     end. The indexer inverts that same curve; the two must move
--     together or banding returns.

local ffi = require("ffi")

local palette = {}

-- Aesthetic knobs (tuning belongs in docs/balance-updates.md):
-- RAMP_GAMMA: how hard ramp steps crowd the dark end.
-- WHITE_STEPS: grays reserved at the top for white-hot cores.
-- MIN_RAMP: below this many steps a hue ramp bands visibly, so a
--   score demanding too many hues is refused rather than seated badly.
-- GRAY_SAT: saturation under which a pixel is "gray enough" for the
--   white ramp.
local RAMP_GAMMA  = 2.0
local WHITE_STEPS = 24
local MIN_RAMP    = 8
local GRAY_SAT    = 0.12

-- The hue vocabulary: names a score may speak, with their base colors
-- in linear light (the splatter deposits energy in these colors; the
-- ramps display them). Extending the vocabulary is adding a row.
palette.hues = {
    ember  = { 1.00, 0.42, 0.10 },
    violet = { 0.55, 0.25, 1.00 },
    teal   = { 0.10, 0.90, 0.80 },
    jade   = { 0.15, 1.00, 0.35 },
    rose   = { 1.00, 0.20, 0.45 },
    gold   = { 1.00, 0.80, 0.15 },
    ice    = { 0.40, 0.70, 1.00 },
}

-- {{{ local function hue_angle_of()
-- The hue's position on the color wheel, in degrees [0,360). Used
-- once per declared hue at build time and once per lit pixel at
-- index time; both sides must agree, so there is exactly one copy.
local function hue_angle_of(r, g, b)
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    -- a gray has no hue; callers check saturation before trusting
    -- the 0 returned here (0 would otherwise read as "red").
    if d == 0 then return 0 end
    local h
    if mx == r then
        h = ((g - b) / d) % 6
    elseif mx == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    return h * 60
end
-- }}}

-- {{{ local function circular_distance()
-- Distance on the color wheel: 350° and 10° are 20° apart, not 340.
local function circular_distance(a, b)
    local d = math.abs(a - b) % 360
    if d > 180 then d = 360 - d end
    return d
end
-- }}}

-- {{{ function palette.hue_color()
-- The splatter asks here what color a named hue's light is. Unknown
-- names are refused with the full legal list — this is the palette's
-- own wall; the compiler dresses it with nearest-word suggestions.
function palette.hue_color(name)
    local base = palette.hues[name]
    if not base then
        local legal = {}
        for k in pairs(palette.hues) do legal[#legal + 1] = k end
        table.sort(legal)
        error("palette: no hue named '" .. tostring(name)
              .. "' — legal hues: " .. table.concat(legal, ", "))
    end
    return base[1], base[2], base[3]
end
-- }}}

-- {{{ function palette.build()
-- Seats the declared hues into 256 slots: black at 0, gray ramp at
-- the top, the rest divided evenly among the hues. Refuses to seat
-- more hues than can each keep MIN_RAMP steps — a silent merge of
-- look-alike ramps would quietly change every gif that used them.
function palette.build(declared)
    if #declared < 1 then
        error("palette: a score must declare at least one hue")
    end
    local seats = 255 - WHITE_STEPS
    local per = math.floor(seats / #declared)
    if per < MIN_RAMP then
        error("palette: cannot seat " .. #declared .. " hues — each "
              .. "would get " .. per .. " steps and the floor is "
              .. MIN_RAMP .. "; declare fewer hues")
    end

    local pal = {
        bytes = ffi.new("uint8_t[?]", 256 * 3),
        ramps = {},                    -- name -> {first, count, angle}
        white = { first = 1 + #declared * per, count = WHITE_STEPS },
        order = {},                    -- declared order, for tests/stats
    }
    -- index 0: black, born zeroed by ffi — the background's seat.

    -- {{{ local function write_entry()
    local function write_entry(index, r, g, b)
        pal.bytes[index * 3]     = math.floor(r * 255 + 0.5)
        pal.bytes[index * 3 + 1] = math.floor(g * 255 + 0.5)
        pal.bytes[index * 3 + 2] = math.floor(b * 255 + 0.5)
    end
    -- }}}

    local next_seat = 1
    for _, name in ipairs(declared) do
        local br, bg, bb = palette.hue_color(name)
        pal.ramps[name] = {
            first = next_seat,
            count = per,
            angle = hue_angle_of(br, bg, bb),
        }
        pal.order[#pal.order + 1] = name
        for j = 0, per - 1 do
            -- gamma-spaced brightness: dark half gets the most steps
            local t = (j / (per - 1)) ^ RAMP_GAMMA
            -- toward the ramp's top, lean gently toward white so the
            -- hand-off to the gray ramp has no visible seam
            local lean = t * t * 0.5
            write_entry(next_seat + j,
                        (br + (1 - br) * lean) * t,
                        (bg + (1 - bg) * lean) * t,
                        (bb + (1 - bb) * lean) * t)
        end
        next_seat = next_seat + per
    end

    -- the gray ramp: full dark-to-white span, same gamma spacing, so
    -- desaturated pixels of any brightness have an honest seat
    for j = 0, WHITE_STEPS - 1 do
        local t = (j / (WHITE_STEPS - 1)) ^ RAMP_GAMMA
        write_entry(pal.white.first + j, t, t, t)
    end

    return pal
end
-- }}}

-- {{{ function palette.index_of()
-- Tone-mapped floats in, palette index out. Arithmetic, not search:
-- brightness gates black, saturation gates gray, hue angle picks a
-- ramp among the declared few, inverted ramp gamma picks the step.
function palette.index_of(pal, r, g, b)
    local v = math.max(r, g, b)
    -- darker than half the darkest ramp step: the background's seat
    if v < 1 / 512 then return 0 end

    local mn = math.min(r, g, b)
    local sat = (v - mn) / v

    local first, count
    if sat < GRAY_SAT then
        first, count = pal.white.first, pal.white.count
    else
        local angle = hue_angle_of(r, g, b)
        local best_name, best_d = nil, 1e9
        for name, ramp in pairs(pal.ramps) do
            local d = circular_distance(angle, ramp.angle)
            -- ties go to whichever pairs() met first; hue angles of
            -- declared ramps are far apart in practice, and a true
            -- tie means both seats show the same color anyway
            if d < best_d then best_d, best_name = d, name end
        end
        local ramp = pal.ramps[best_name]
        first, count = ramp.first, ramp.count
    end

    -- invert the ramp's gamma spacing to find the step; the two
    -- curves must mirror each other (see the file-head note)
    local step = math.floor((v ^ (1 / RAMP_GAMMA)) * count)
    if step > count - 1 then step = count - 1 end
    return first + step
end
-- }}}

return palette
