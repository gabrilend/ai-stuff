-- 024-compile.lua — the compiler and its validation wall: a raw
-- score in, a ready timeline out, or every mistake at once.
--
-- What this is, generally: validation first, everything together —
-- a score author fixes one render's worth of mistakes per attempt,
-- not one mistake. Every error names its stroke and field, and when
-- a name misses a vocabulary it carries the nearest legal word
-- (computed by edit distance against the same tables the runtime
-- trusts — nothing here keeps a second copy that could drift).
-- Compilation then resolves every name to a number: clock words to
-- angles, hue names to palette seats, easing and fade names to
-- functions, tip borrowings to coordinates. The timeline that comes
-- out contains no strings to look up at runtime.

local palette = require("002-palette")
local emit = require("008-emit")
local paths = require("014-paths")
local easing = require("016-easing")
local tracks = require("018-tracks")
local fills = require("020-fills")
local pool = require("006-pool")
local score = require("022-score")

local compile = {}

-- The frame rates GIF can keep honestly: delays are whole
-- hundredths of a second, so fps must divide 100 or the file drifts
-- from the score's clock.
local LEGAL_FPS = { [50]=true, [25]=true, [20]=true, [10]=true,
                    [5]=true, [4]=true, [2]=true, [1]=true }

-- {{{ local function edit_distance()
-- Levenshtein, the plain dynamic program — small words, small cost.
local function edit_distance(a, b)
    local la, lb = #a, #b
    local row = {}
    for j = 0, lb do row[j] = j end
    for i = 1, la do
        local prev = row[0]
        row[0] = i
        for j = 1, lb do
            local cur = row[j]
            local cost = (a:byte(i) == b:byte(j)) and 0 or 1
            local best = math.min(row[j] + 1, row[j - 1] + 1,
                                  prev + cost)
            row[j] = best
            prev = cur
        end
    end
    return row[lb]
end
-- }}}

-- {{{ local function nearest()
-- The closest legal word to a miss — the wall's teaching voice,
-- quoted back to humans and to the porch's models alike.
local function nearest(word, candidates)
    local best, best_d = nil, math.huge
    for _, c in ipairs(candidates) do
        local d = edit_distance(tostring(word), c)
        if d < best_d then best, best_d = c, d end
    end
    return best
end
-- }}}

-- {{{ local function keys_of()
local function keys_of(tbl)
    local list = {}
    for k in pairs(tbl) do list[#list + 1] = k end
    table.sort(list)
    return list
end
-- }}}

-- {{{ local function is_tenths()
-- The score speaks time in tenths of a second — one decimal place.
local function is_tenths(x)
    return math.abs(x * 10 - math.floor(x * 10 + 0.5)) < 1e-9
end
-- }}}

-- {{{ local function is_point()
local function is_point(v)
    return type(v) == "table" and type(v[1]) == "number"
           and type(v[2]) == "number" and v.ref == nil
end
-- }}}

-- {{{ local function is_tip()
local function is_tip(v)
    return type(v) == "table" and v.ref == "tip"
end
-- }}}

-- {{{ function compile.score()
-- The whole passage: wall first, then resolution, then tracks.
function compile.score(raw)
    local errs = {}
    -- {{{ local function fail()
    local function fail(who, message)
        errs[#errs + 1] = who .. ": " .. message
    end
    -- }}}

    -- ---- the canvas ----
    local cv = raw.canvas
    local who = "canvas"
    if type(cv.size) ~= "number" or cv.size < 16 then
        fail(who, "size must be a number of at least 16 pixels, got "
             .. tostring(cv.size))
    end
    if not LEGAL_FPS[cv.fps] then
        fail(who, "fps must divide 100 evenly (50, 25, 20, 10, 5, 4, "
             .. "2, 1) because gif delays are whole hundredths of a "
             .. "second — got " .. tostring(cv.fps))
    end
    if type(cv.length) ~= "number" or cv.length <= 0
       or not is_tenths(cv.length) then
        fail(who, "length must be positive seconds spoken in tenths, "
             .. "got " .. tostring(cv.length))
    end
    if type(cv.seed) ~= "number" or cv.seed % 1 ~= 0 then
        fail(who, "seed must be a whole number, got "
             .. tostring(cv.seed))
    end
    local gx, gy = 0, 0
    if cv.gravity ~= nil then
        if is_point(cv.gravity) then
            gx, gy = cv.gravity[1], cv.gravity[2]
        else
            fail(who, "gravity must be a { x, y } pair of numbers")
        end
    end

    -- ---- the strokes: names first (landmarks may look forward) ----
    local by_name = {}
    for i, s in ipairs(raw.strokes) do
        if s.name ~= nil then
            if type(s.name) ~= "string" then
                fail("stroke #" .. i, "a name must be a string")
            elseif by_name[s.name] then
                fail("stroke '" .. s.name .. "' (#" .. i .. ")",
                     "this name is already taken by stroke #"
                     .. by_name[s.name].index
                     .. " — names must be unique to be borrowed")
            else
                by_name[s.name] = { stroke = s, index = i }
            end
        end
    end

    -- {{{ local function check_anchor()
    -- a coordinate that may be a literal point or a tip borrowing
    local function check_anchor(who_, field, v)
        if is_point(v) then return end
        if is_tip(v) then
            local target = by_name[v.of]
            if not target then
                fail(who_, field .. " borrows tip(\"" .. tostring(v.of)
                     .. "\") but no stroke bears that name")
            elseif type(target.stroke.shape) == "table"
                   and target.stroke.shape.kind == "fill" then
                fail(who_, field .. " borrows the tip of '" .. v.of
                     .. "', but fills are regions — a region has no "
                     .. "tip to borrow")
            end
            return
        end
        fail(who_, field .. " must be a { x, y } point or a "
             .. "tip(\"name\") borrowing")
    end
    -- }}}

    local hue_words = keys_of(palette.hues)
    local ease_words = keys_of(easing.EASINGS)
    local fade_words = keys_of(easing.ENVELOPES)
    local emit_words = keys_of(emit.DEFAULTS)

    for i, s in ipairs(raw.strokes) do
        local label = s.name and ("stroke '" .. s.name .. "' (#" .. i .. ")")
                      or ("stroke #" .. i)

        -- time speaks in tenths, inside the canvas's length
        if type(s.at) ~= "number" or s.at < 0 or not is_tenths(s.at) then
            fail(label, "at must be seconds spoken in tenths (one "
                 .. "decimal place), from zero — got " .. tostring(s.at))
        end
        if type(s.lasts) ~= "number" or s.lasts <= 0
           or not is_tenths(s.lasts) then
            fail(label, "lasts must be positive seconds spoken in "
                 .. "tenths — got " .. tostring(s.lasts))
        end
        if type(s.at) == "number" and type(s.lasts) == "number"
           and type(cv.length) == "number"
           and s.at + s.lasts > cv.length + 1e-9 then
            fail(label, "runs until " .. (s.at + s.lasts)
                 .. "s but the canvas ends at " .. cv.length .. "s")
        end

        -- vocabulary words, each with its teacher
        if type(s.color) ~= "string" or not palette.hues[s.color] then
            fail(label, "no hue named '" .. tostring(s.color)
                 .. "' — nearest legal: "
                 .. tostring(nearest(s.color, hue_words)))
        end
        if type(s.fade) ~= "string" or not easing.ENVELOPES[s.fade] then
            fail(label, "no fade envelope named '" .. tostring(s.fade)
                 .. "' — nearest legal: "
                 .. tostring(nearest(s.fade, fade_words)))
        end
        if s.ease ~= nil and not easing.EASINGS[s.ease] then
            fail(label, "no easing named '" .. tostring(s.ease)
                 .. "' — nearest legal: "
                 .. tostring(nearest(s.ease, ease_words)))
        end
        if s.emit ~= nil then
            if type(s.emit) ~= "table" then
                fail(label, "emit must be a table of overrides")
            else
                for k in pairs(s.emit) do
                    if emit.DEFAULTS[k] == nil then
                        fail(label, "no emit field named '"
                             .. tostring(k) .. "' — nearest legal: "
                             .. tostring(nearest(k, emit_words)))
                    end
                end
            end
        end

        -- the shape
        local sh = s.shape
        if type(sh) ~= "table" or sh.kind == nil then
            fail(label, "shape must be arc{...}, line{...}, "
                 .. "point{...}, or fill{...}")
        elseif sh.kind == "arc" then
            if not is_point(sh.center) then
                fail(label, "an arc needs center = { x, y }")
            end
            if type(sh.radius) ~= "number" or sh.radius <= 0 then
                fail(label, "an arc needs a positive radius")
            end
            local from_ok = pcall(paths.clock_angle, sh.from)
            local to_ok = pcall(paths.clock_angle, sh.to)
            if not from_ok then
                fail(label, "cannot read the arc's from position '"
                     .. tostring(sh.from) .. "' — say 7 or \"7 o'clock\"")
            end
            if not to_ok then
                fail(label, "cannot read the arc's to position '"
                     .. tostring(sh.to) .. "'")
            end
            if sh.turn ~= "clockwise" and sh.turn ~= "counterclockwise" then
                fail(label, "an arc needs turn = \"clockwise\" or "
                     .. "\"counterclockwise\" — nearest to '"
                     .. tostring(sh.turn) .. "': "
                     .. tostring(nearest(sh.turn,
                        { "clockwise", "counterclockwise" })))
            end
        elseif sh.kind == "line" then
            check_anchor(label, "line.from", sh.from)
            check_anchor(label, "line.to", sh.to)
        elseif sh.kind == "point" then
            check_anchor(label, "point.at", sh.at)
        elseif sh.kind == "fill" then
            if type(sh.vertices) ~= "table" or #sh.vertices < 2 then
                fail(label, "a fill needs at least two vertices")
            else
                for v, vert in ipairs(sh.vertices) do
                    check_anchor(label, "fill vertex " .. v, vert)
                end
            end
            local legal = #(sh.vertices or {}) == 2
                          and { "at-once", "along" }
                          or { "at-once", "downward", "radial" }
            local legal_set = {}
            for _, w in ipairs(legal) do legal_set[w] = true end
            if not legal_set[sh.sweep] then
                fail(label, "no sweep named '" .. tostring(sh.sweep)
                     .. "' for this region — nearest legal: "
                     .. tostring(nearest(sh.sweep, legal)))
            end
        else
            fail(label, "no shape kind named '" .. tostring(sh.kind)
                 .. "' — nearest legal: " .. tostring(nearest(sh.kind,
                    { "arc", "line", "point", "fill" })))
        end
    end

    if #errs > 0 then
        error("the score fails its wall (" .. #errs .. " error"
              .. (#errs == 1 and "" or "s") .. "):\n  "
              .. table.concat(errs, "\n  "), 0)
    end

    -- ---- resolution: names become numbers ----
    -- play order first: emission order is the random stream's order
    local sorted = {}
    for _, s in ipairs(raw.strokes) do
        score.insert(sorted, s)
    end

    -- hues seat in order of first use in play order
    local declared, hue_index = {}, {}
    for _, s in ipairs(sorted) do
        if hue_index[s.color] == nil then
            declared[#declared + 1] = s.color
            hue_index[s.color] = #declared - 1
        end
    end
    local pal = palette.build(declared)

    -- landmark resolution, cycles refused (a line may borrow a tip
    -- of a line that borrows a tip — but never its own tail)
    local resolving, resolved = {}, {}
    local build_path  -- declared ahead: resolve and build recurse
    -- {{{ local function resolve_anchor()
    local function resolve_anchor(v)
        if is_point(v) then return { v[1], v[2] } end
        local name = v.of
        if resolved[name] then return resolved[name] end
        if resolving[name] then
            error("the score fails its wall (1 error):\n  stroke '"
                  .. name .. "': its tip borrows itself around a "
                  .. "circle of borrowings — someone must stand on "
                  .. "solid ground", 0)
        end
        resolving[name] = true
        local target = by_name[name].stroke
        local path = build_path(target)
        local x, y = path.at(1)
        resolving[name] = nil
        resolved[name] = { x, y }
        return resolved[name]
    end
    -- }}}
    -- {{{ build_path()
    -- a spot stroke's geometry, landmarks resolved along the way
    build_path = function(s)
        local sh = s.shape
        if sh.kind == "arc" then
            return paths.arc{ center = sh.center, radius = sh.radius,
                              from = sh.from, to = sh.to,
                              turn = sh.turn }
        elseif sh.kind == "line" then
            return paths.line{ from = resolve_anchor(sh.from),
                               to = resolve_anchor(sh.to) }
        else
            return paths.point{ at = resolve_anchor(sh.at) }
        end
    end
    -- }}}

    local list = {}
    local demands = {}
    for _, s in ipairs(sorted) do
        local recipe = emit.recipe(s.emit, hue_index[s.color])
        local ease_fn = easing.motion(s.ease or "linear")
        local env_fn = easing.envelope(s.fade)
        local tr
        if s.shape.kind == "fill" then
            local verts = {}
            for v, vert in ipairs(s.shape.vertices) do
                verts[v] = resolve_anchor(vert)
            end
            tr = fills.track{
                name = s.name or "fill", from = s.at, lasts = s.lasts,
                ease = ease_fn, envelope = env_fn,
                region = fills.region{ vertices = verts,
                                       sweep = s.shape.sweep },
                recipe = recipe,
            }
        else
            tr = tracks.track{
                name = s.name or s.shape.kind, from = s.at,
                lasts = s.lasts, ease = ease_fn, envelope = env_fn,
                path = build_path(s), recipe = recipe,
            }
        end
        list[#list + 1] = tr
        demands[#demands + 1] = { rate = recipe.rate,
                                  life = recipe.life,
                                  from = s.at, upto = s.at + s.lasts }
    end

    return {
        canvas = { size = cv.size, fps = cv.fps, length = cv.length,
                   seed = cv.seed },
        hues = declared,
        pal = pal,
        timeline = tracks.timeline(list, gx, gy),
        capacity = pool.size_for(demands),
    }
end
-- }}}

return compile
