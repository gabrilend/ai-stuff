-- 024-compile.lua — the compiler and its validation wall: a raw
-- score in, a ready timeline out, or every mistake at once.
--
-- What this is, generally: validation first, everything together —
-- a score author fixes one render's worth of mistakes per attempt,
-- not one mistake. Every error names its stroke and field, and when
-- a name misses a vocabulary it carries the nearest legal word
-- (computed by edit distance, 047-nearest.lua, against the same tables
-- the runtime trusts — nothing here keeps a second copy that could
-- drift).
-- Compilation then resolves every name to a number: clock words to
-- angles, hue names to palette seats, easing and fade names to
-- functions, tip borrowings to coordinates. The timeline that comes
-- out contains no strings to look up at runtime.
--
-- A score may also speak the second space (issue 701d): shapes, a
-- camera and a world, judged by the 3D wall (049-shape-wall.lua) in
-- the same pass, so a score with a broken stroke and a misspelled
-- shape hears about both at once; and panes of glass, each stroke
-- painted on one. Such a score compiles to one stroke timeline per
-- pane, the loaded world, and the landmarks a stroke follows a shape
-- by (`studio` in the result). A score with only strokes on the front
-- pane compiles exactly as it always has.

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

-- The nearest legal word to a miss, shared with the 3D wall.
local nearest = require("047-nearest").word

-- The house hues in their one fixed order: a score with a second space
-- seats all of them, as every shape film does, so its shapes and strokes
-- index through the same palette as the films (039-shape-films.lua).
compile.HOUSE_HUES = { "rose", "ember", "gold", "jade", "teal", "ice",
                       "violet" }

-- How brightly a hue background glows behind everything, as light. Low,
-- so it reads as a tinted dark rather than a coloured wall; an aesthetic
-- knob (docs/balance-updates.md).
local BACKGROUND_GLOW = 0.05

-- The words of a pane{}; the ones only a pane in the world takes.
local PANE_WORDS = { "name", "place", "at", "facing", "size", "pixels" }
local WORLD_PANE_WORDS = { "at", "facing", "size", "pixels" }

-- A scene's words the score says elsewhere: its canvas{} says the size
-- and the length, the camera{} and shape{} calls the rest; one process
-- renders a score, so there are no jobs to split.
local SAID_ELSEWHERE = {
    name = "the score is named by its file",
    size = "say it in canvas{}", frames = "say it in canvas{}",
    delay_cs = "canvas{ fps = ... } sets it", jobs = "a score renders in one process",
    camera = "say it in camera{}", instances = "each shape is its own shape{}",
}

-- The 3D half, loaded only by a score that has shapes (the stroke-only
-- scores never pay for it). Loaded beside this file, as the films do.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local three
-- {{{ local function three_d()
local function three_d()
    if not three then
        three = {
            meshes = dofile(HERE .. "034-meshes.lua"),
            choreography = dofile(HERE .. "035-choreography.lua"),
            fluid = dofile(HERE .. "037-fluid.lua"),
            raster = dofile(HERE .. "036-raster.lua"),
            words = dofile(HERE .. "048-shape-words.lua"),
            wall = dofile(HERE .. "049-shape-wall.lua"),
        }
        -- every house hue as light, and "cloud", white light, as the
        -- films hand them in
        local hue_table = {}
        for _, hue in ipairs(compile.HOUSE_HUES) do
            hue_table[hue] = { palette.hue_color(hue) }
        end
        hue_table.cloud = { 1, 1, 1 }
        three.hues = hue_table
    end
    return three
end
-- }}}

-- {{{ local function copy()
-- A deep copy: the stage manager builds into the scene it loads, and
-- the score's own tables must stay as written (the writer reads them).
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, item in pairs(v) do out[k] = copy(item) end
    return out
end
-- }}}

-- {{{ local function score_path()
-- A 3D wall line, said in the score's own terms: scene.instances[3]
-- is the third shape{}, scene.camera the camera{}, and the rest of the
-- scene is the world{}.
local function score_path(line)
    local said = line:gsub("^scene%.instances%[(%d+)%]", "shape #%1")
    said = said:gsub("^scene%.camera", "camera")
    said = said:gsub("^scene([%.:])", "world%1")
    return said
end
-- }}}

-- {{{ local function shape_tags()
-- Every tag a shape{} or one of its parts bears.
local function shape_tags(list, into)
    for _, sh in ipairs(list) do
        if type(sh) == "table" then
            if type(sh.tag) == "string" then into[sh.tag] = true end
            if type(sh.parts) == "table" then shape_tags(sh.parts, into) end
        end
    end
    return into
end
-- }}}

-- {{{ local function live_paths()
-- Paths with an end that follows a shape: the cell is a { x, y } pair
-- the renderer rewrites each frame with where the shape appears, so
-- the path is measured anew every time it is asked.
local function live_point(cell)
    return {
        kind = "point",
        at = function() return cell[1], cell[2] end,
        heading = function() return 0, 0 end,
    }
end
local function live_line(a, b)
    return {
        kind = "line",
        at = function(t)
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        end,
        heading = function()
            local dx, dy = b[1] - a[1], b[2] - a[2]
            local len = math.sqrt(dx * dx + dy * dy)
            if len == 0 then return 0, 0 end
            return dx / len, dy / len
        end,
    }
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
    -- the length in seconds, or (for a loop of shapes, which counts
    -- frames) in frames; one or the other
    local length = cv.length
    if cv.frames ~= nil then
        if cv.length ~= nil then
            fail(who, "say length or frames, not both — they are one "
                 .. "fact said twice")
        elseif type(cv.frames) ~= "number" or cv.frames < 1
               or cv.frames % 1 ~= 0 then
            fail(who, "frames must be a whole number of at least 1, got "
                 .. tostring(cv.frames))
        elseif LEGAL_FPS[cv.fps] then
            length = cv.frames / cv.fps
        end
    elseif type(cv.length) ~= "number" or cv.length <= 0
       or not is_tenths(cv.length) then
        fail(who, "length must be positive seconds spoken in tenths, "
             .. "got " .. tostring(cv.length))
    end
    -- the background is the score's to say: black, a hue's dark glow,
    -- or the sky (the world's stars)
    local bg = cv.background
    if bg ~= nil and bg ~= "black" and bg ~= "sky"
       and not (type(bg) == "string" and palette.hues[bg]) then
        local legal = { "black", "sky" }
        for _, h in ipairs(keys_of(palette.hues)) do legal[#legal + 1] = h end
        fail(who, "no background named '" .. tostring(bg) .. "' — say "
             .. "\"black\", \"sky\" (the world's stars) or a hue; "
             .. "nearest legal: " .. tostring(nearest(bg, legal)))
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

    -- ---- the panes: the front one is always there ----
    local pane_set = {}
    for _, w in ipairs(PANE_WORDS) do pane_set[w] = true end
    local panes_by_name = { front = { place = "front", index = 0 } }
    local pane_names = { "front" }
    local has_world = #(raw.shapes or {}) > 0
    for i, pn in ipairs(raw.panes or {}) do
        local plabel = "pane #" .. i
        if type(pn) ~= "table" then
            fail(plabel, "pane{...} wants a table")
        else
            if type(pn.name) == "string" then
                plabel = "pane '" .. pn.name .. "' (#" .. i .. ")"
            end
            for k in pairs(pn) do
                if not pane_set[k] then
                    fail(plabel, "no pane word '" .. tostring(k)
                         .. "' — nearest legal: "
                         .. tostring(nearest(k, PANE_WORDS)))
                end
            end
            local place = pn.place == nil and "world" or pn.place
            if place ~= "front" and place ~= "back" and place ~= "world" then
                fail(plabel, "no place '" .. tostring(place) .. "' — a "
                     .. "pane sits at the camera's \"front\", its "
                     .. "\"back\", or in the \"world\"; nearest legal: "
                     .. tostring(nearest(place, { "front", "back", "world" })))
            end
            if type(pn.name) ~= "string" then
                fail(plabel, "a pane needs a name, for strokes to be "
                     .. "painted on it")
            elseif pn.name == "front" then
                fail(plabel, "\"front\" is the pane a stroke with no "
                     .. "pane is painted on; give this one its own name")
            elseif panes_by_name[pn.name] then
                fail(plabel, "this name is already taken by pane #"
                     .. panes_by_name[pn.name].index)
            else
                panes_by_name[pn.name] = { place = place, index = i }
                pane_names[#pane_names + 1] = pn.name
            end
            if place == "world" then
                if not has_world then
                    fail(plabel, "a pane in the world needs a world to "
                         .. "stand in — this score has no shape{}")
                end
                local function triple(v)
                    return type(v) == "table" and type(v[1]) == "number"
                           and type(v[2]) == "number" and type(v[3]) == "number"
                end
                if not triple(pn.at) then
                    fail(plabel, "a pane in the world needs at = { x, y, z }, "
                         .. "its middle in world units")
                end
                if not triple(pn.facing) or (pn.facing[1] == 0
                   and pn.facing[2] == 0 and pn.facing[3] == 0) then
                    fail(plabel, "a pane in the world needs facing = "
                         .. "{ x, y, z }, the way its front looks")
                end
                if type(pn.size) ~= "table" or type(pn.size[1]) ~= "number"
                   or type(pn.size[2]) ~= "number" or pn.size[1] <= 0
                   or pn.size[2] <= 0 then
                    fail(plabel, "a pane in the world needs size = "
                         .. "{ width, height }, in world units")
                end
                if type(pn.pixels) ~= "number" or pn.pixels % 1 ~= 0
                   or pn.pixels < 8 or pn.pixels > 1024 then
                    fail(plabel, "a pane in the world needs pixels, a whole "
                         .. "number from 8 to 1024: its width in pixels")
                end
            elseif place == "front" or place == "back" then
                for _, k in ipairs(WORLD_PANE_WORDS) do
                    if pn[k] ~= nil then
                        fail(plabel, "a pane at the camera covers the whole "
                             .. "frame; `" .. k .. "` belongs to a pane in "
                             .. "the world")
                    end
                end
            end
        end
    end

    -- the names a tip may borrow: strokes, and shapes' tags
    local tags = shape_tags(raw.shapes or {}, {})
    local borrowable = keys_of(by_name)
    for tag in pairs(tags) do
        if by_name[tag] then
            fail("stroke '" .. tag .. "' (#" .. by_name[tag].index .. ")",
                 "a shape bears this name too — tip(\"" .. tag .. "\") "
                 .. "would not know which is meant")
        else
            borrowable[#borrowable + 1] = tag
        end
    end

    -- {{{ local function follows_shape()
    -- does this stroke's own geometry follow a shape (and so never stand
    -- still)?
    local function follows_shape(s)
        local sh = s.shape
        if type(sh) ~= "table" then return false end
        for _, v in ipairs({ sh.from or false, sh.to or false, sh.at or false }) do
            if is_tip(v) and tags[v.of] and not by_name[v.of] then return true end
        end
        return false
    end
    -- }}}

    -- {{{ local function check_anchor()
    -- a coordinate that may be a literal point or a tip borrowing: of a
    -- stroke on the same pane, or of a shape, seen from a camera's pane
    local function check_anchor(who_, field, v, on_pane, place, in_fill)
        if is_point(v) then return end
        if is_tip(v) then
            local target = by_name[v.of]
            if target then
                if type(target.stroke.shape) == "table"
                   and target.stroke.shape.kind == "fill" then
                    fail(who_, field .. " borrows the tip of '" .. v.of
                         .. "', but fills are regions — a region has no "
                         .. "tip to borrow")
                elseif (target.stroke.pane or "front") ~= on_pane then
                    fail(who_, field .. " borrows the tip of '" .. v.of
                         .. "', which is painted on another pane — a tip "
                         .. "is a spot on its own pane")
                elseif follows_shape(target.stroke) then
                    fail(who_, field .. " borrows the tip of '" .. v.of
                         .. "', which follows a shape and never stands "
                         .. "still; follow the shape itself")
                end
            elseif tags[v.of] then
                if place == "world" then
                    fail(who_, field .. " follows the shape '" .. v.of
                         .. "', but only a pane at the camera sees where a "
                         .. "shape appears")
                elseif in_fill then
                    fail(who_, field .. " follows the shape '" .. v.of
                         .. "', but a fill's corners must stand still")
                end
            elseif has_world then
                fail(who_, field .. " borrows tip(\"" .. tostring(v.of)
                     .. "\") but no stroke or shape bears that name — "
                     .. "nearest: " .. tostring(nearest(v.of, borrowable)))
            else
                fail(who_, field .. " borrows tip(\"" .. tostring(v.of)
                     .. "\") but no stroke bears that name")
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
        local on_pane = s.pane == nil and "front" or s.pane
        local pane_info = panes_by_name[on_pane]
        if not pane_info then
            fail(label, "no pane named '" .. tostring(s.pane)
                 .. "' — nearest legal: "
                 .. tostring(nearest(s.pane, pane_names)))
        end
        local place = pane_info and pane_info.place or "front"

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
           and type(length) == "number"
           and s.at + s.lasts > length + 1e-9 then
            fail(label, "runs until " .. (s.at + s.lasts)
                 .. "s but the canvas ends at " .. length .. "s")
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
            check_anchor(label, "line.from", sh.from, on_pane, place)
            check_anchor(label, "line.to", sh.to, on_pane, place)
        elseif sh.kind == "point" then
            check_anchor(label, "point.at", sh.at, on_pane, place)
        elseif sh.kind == "fill" then
            if type(sh.vertices) ~= "table" or #sh.vertices < 2 then
                fail(label, "a fill needs at least two vertices")
            else
                for v, vert in ipairs(sh.vertices) do
                    check_anchor(label, "fill vertex " .. v, vert, on_pane,
                                 place, true)
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

    -- ---- the second space: shapes, camera and world, at the 3D wall ----
    local total = cv.frames
    if total == nil and type(length) == "number" and LEGAL_FPS[cv.fps] then
        total = math.floor(length * cv.fps + 0.5)
    end
    local scene
    if (raw.camera ~= nil or raw.world ~= nil) and not has_world then
        fail("world", "a camera or a world with no shape{} has nothing "
             .. "to film")
    end
    if bg == "sky" and not (type(raw.world) == "table" and raw.world.stars) then
        fail(who, "background = \"sky\" is the world's stars; say "
             .. "world{ stars = { ... } } (and at least one shape{})")
    end
    if has_world then
        local t3 = three_d()
        local world = raw.world or {}
        if type(world) ~= "table" then
            fail("world", "world{...} wants a table")
            world = {}
        end
        local world_words, world_set = {}, {}
        for _, entry in ipairs(t3.words.CONTEXTS.scene) do
            if not SAID_ELSEWHERE[entry[1]] then
                world_words[#world_words + 1] = entry[1]
                world_set[entry[1]] = true
            end
        end
        scene = {
            name = "score",
            -- stand-ins where the canvas is already refused, so its
            -- mistakes are told once
            size = (type(cv.size) == "number" and cv.size >= 16
                    and cv.size % 1 == 0) and cv.size or 16,
            frames = (type(total) == "number" and total >= 1
                      and total % 1 == 0) and total or 1,
            camera = copy(raw.camera),
            instances = copy(raw.shapes),
        }
        for k, v in pairs(world) do
            if SAID_ELSEWHERE[k] then
                fail("world", "`" .. tostring(k) .. "` is not a world word: "
                     .. SAID_ELSEWHERE[k])
            elseif world_set[k] then
                scene[k] = copy(v)
            else
                fail("world", "no word '" .. tostring(k) .. "' in a world "
                     .. "— nearest legal: "
                     .. tostring(nearest(k, world_words)))
            end
        end
        if world.stars and bg ~= "sky" then
            fail("world", "stars are the sky behind everything; say "
                 .. "canvas{ background = \"sky\" } to show them")
        end
        local vocab = t3.wall.vocabulary(t3.hues, t3.meshes, t3.choreography)
        for _, line in ipairs(t3.wall.check(scene, vocab)) do
            errs[#errs + 1] = score_path(line)
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

    -- landmark resolution, cycles refused (a line may borrow a tip
    -- of a line that borrows a tip — but never its own tail); a tip
    -- of a shape is a cell the renderer moves each frame
    local resolving, resolved = {}, {}
    local cells = {}
    local build_path  -- declared ahead: resolve and build recurse
    -- {{{ local function resolve_anchor()
    local function resolve_anchor(v)
        if is_point(v) then return { v[1], v[2] } end
        local name = v.of
        if not by_name[name] then
            cells[name] = cells[name] or { 0, 0, live = true }
            return cells[name]
        end
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
            local a, b = resolve_anchor(sh.from), resolve_anchor(sh.to)
            if a.live or b.live then return live_line(a, b) end
            return paths.line{ from = a, to = b }
        else
            local at = resolve_anchor(sh.at)
            if at.live then return live_point(at) end
            return paths.point{ at = at }
        end
    end
    -- }}}

    -- {{{ local function strokes_to_timeline()
    -- One pane's strokes (in play order) into its timeline: hues seat
    -- in order of first use in play order.
    local function strokes_to_timeline(list_in)
        local declared, hue_index = {}, {}
        for _, s in ipairs(list_in) do
            if hue_index[s.color] == nil then
                declared[#declared + 1] = s.color
                hue_index[s.color] = #declared - 1
            end
        end

        local list = {}
        local demands = {}
        for _, s in ipairs(list_in) do
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
        return declared, tracks.timeline(list, gx, gy),
               #demands > 0 and pool.size_for(demands) or 0
    end
    -- }}}

    local canvas_out = { size = cv.size, fps = cv.fps, length = length,
                         seed = cv.seed }

    -- a score of strokes on the front pane alone, on black: exactly as
    -- it has always compiled
    local plain = not has_world and #(raw.panes or {}) == 0
                  and (bg == nil or bg == "black")
    if plain then
        local declared, timeline, capacity = strokes_to_timeline(sorted)
        return {
            canvas = canvas_out,
            hues = declared,
            pal = palette.build(declared),
            timeline = timeline,
            capacity = capacity,
        }
    end

    -- ---- two spaces: a timeline per pane, the world, the landmarks ----
    local panes = { { name = "front", place = "front",
                      width = cv.size, height = cv.size } }
    for _, pn in ipairs(raw.panes or {}) do
        local place = pn.place or "world"
        local pane = { name = pn.name, place = place,
                       width = cv.size, height = cv.size }
        if place == "world" then
            pane.at = { pn.at[1], pn.at[2], pn.at[3] }
            pane.facing = { pn.facing[1], pn.facing[2], pn.facing[3] }
            pane.size = { pn.size[1], pn.size[2] }
            pane.width = pn.pixels
            pane.height = math.max(1, math.floor(pn.pixels * pn.size[2]
                                                 / pn.size[1] + 0.5))
        end
        panes[#panes + 1] = pane
    end
    for k, pane in ipairs(panes) do
        local mine = {}
        for _, s in ipairs(sorted) do
            if (s.pane or "front") == pane.name then mine[#mine + 1] = s end
        end
        pane.strokes = #mine
        -- each pane its own random stream; the front pane keeps the
        -- canvas's seed
        pane.seed = cv.seed + k - 1
        pane.hues, pane.timeline, pane.capacity = strokes_to_timeline(mine)
    end

    if has_world then
        local t3 = three_d()
        scene.name = "score"
        t3.choreography.load(scene, t3.hues, t3.meshes, t3.fluid)
    end

    local background
    if bg ~= nil and bg ~= "black" and bg ~= "sky" then
        local r, g, b = palette.hue_color(bg)
        background = { r * BACKGROUND_GLOW, g * BACKGROUND_GLOW,
                       b * BACKGROUND_GLOW }
    end

    local front = panes[1]
    return {
        canvas = canvas_out,
        hues = front.hues,
        pal = palette.build(compile.HOUSE_HUES),
        timeline = front.timeline,
        capacity = front.capacity,
        studio = {
            frames = total,
            panes = panes,
            world = scene,
            background = background,
            landmarks = cells,
            three = has_world and three_d() or nil,
        },
    }
end
-- }}}

return compile
