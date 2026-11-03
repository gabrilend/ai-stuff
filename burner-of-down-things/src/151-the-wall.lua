-- 151-the-wall.lua
--
-- The paintbrush and its wall (docs/067, issue 802): the machinery every
-- end shares. A canvas is a Lua file of plain data, loaded with an empty
-- environment except the paintbrush's own constructors (`line{…}`,
-- `surface{…}`, …): the language is the parser, and the table of
-- constructors is the grammar. The wall collects every unknown word,
-- unknown field, wrong type, missing field and dangling reference, each
-- with its line and the nearest legal word, and reports them all together;
-- nothing is quietly filled in, and an absent optional field takes the
-- default the paintbrush document publishes. Compilation resolves every
-- name to a number once, into flat parallel arrays. The document is
-- generated from the same table, so the two cannot drift.
--
-- A paintbrush is a table { name, words = { [word] = { doc, once, required,
-- fields = { [field] = { type, required, default, doc } }, order } } }.
-- PNG below is the `.png` end's; another end's paintbrush is another such
-- table handed to the same `load`, `compile` and `document`.

local the_look = require("070-the-look")

local wall = {}

-- {{{ local function distance
-- Levenshtein distance by bytes, for "the nearest legal word".
local function distance(a, b)
    local previous = {}
    for j = 0, #b do
        previous[j] = j
    end
    for i = 1, #a do
        local current = { [0] = i }
        for j = 1, #b do
            local cost = (a:byte(i) == b:byte(j)) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end
-- }}}

-- {{{ function wall.nearest
-- The legal name nearest to `word`, ties by name; nil when none is given.
function wall.nearest(word, names)
    local best, best_d
    for _, name in ipairs(names) do
        local d = distance(tostring(word), name)
        if not best or d < best_d or (d == best_d and name < best) then
            best, best_d = name, d
        end
    end
    return best
end
-- }}}

-- {{{ local function sorted_keys
local function sorted_keys(t)
    local out = {}
    for k in pairs(t) do
        out[#out + 1] = k
    end
    table.sort(out)
    return out
end
-- }}}

-- The studio's categories (docs/010 question 14).
wall.CATEGORIES = { "card", "chart", "clip", "diagram", "note", "source", "still" }

-- {{{ Types
-- Each type: a check returning nil when the value fits, or a sentence
-- saying what was found, and a description for the document.
local function is_number(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function is_point(v) return type(v) == "table" and #v == 2 and is_number(v[1]) and is_number(v[2]) end

local function describe(v)
    if type(v) == "string" then return "the text '" .. v .. "'" end
    if type(v) == "table" then return "a table" end
    return "the " .. type(v) .. " " .. tostring(v)
end

wall.TYPES = {
    whole = { doc = "a whole number, 0 or more", check = function(v)
        if not (is_number(v) and v >= 0 and v % 1 == 0) then return "wants a whole number, got " .. describe(v) end
    end },
    positive = { doc = "a whole number, 1 or more", check = function(v)
        if not (is_number(v) and v >= 1 and v % 1 == 0) then return "wants a whole number from 1, got " .. describe(v) end
    end },
    number = { doc = "a number", check = function(v)
        if not is_number(v) then return "wants a number, got " .. describe(v) end
    end },
    text = { doc = "a string", check = function(v)
        if type(v) ~= "string" then return "wants text, got " .. describe(v) end
    end },
    name = { doc = "a name: letters, digits, `-` and `_`, starting with a letter", check = function(v)
        if type(v) ~= "string" or not v:match("^%a[%w_%-]*$") then return "wants a name, got " .. describe(v) end
    end },
    point = { doc = "`{x, y}`, two numbers, in pixels from the top left", check = function(v)
        if not is_point(v) then return "wants a point {x, y}, got " .. describe(v) end
    end },
    points = { doc = "`{{x, y}, …}`, three points or more", check = function(v)
        if type(v) ~= "table" or #v < 3 then return "wants three points or more" end
        for i, p in ipairs(v) do
            if not is_point(p) then return "point " .. i .. " is not {x, y}" end
        end
    end },
    place = { doc = "a point `{x, y}`, or the name of a named surface (its middle)", check = function(v)
        if not is_point(v) and not (type(v) == "string" and v:match("^%a[%w_%-]*$")) then
            return "wants a point {x, y} or a surface's name, got " .. describe(v)
        end
    end },
    colour = { doc = "`{r, g, b}` or `{r, g, b, a}`, each 0-255", check = function(v)
        if type(v) ~= "table" or (#v ~= 3 and #v ~= 4) then return "wants {r, g, b} or {r, g, b, a}" end
        for i = 1, #v do
            if not (is_number(v[i]) and v[i] >= 0 and v[i] <= 255) then return "channel " .. i .. " is not 0-255" end
        end
    end },
    numbers = { doc = "`{n, …}`, one number or more", check = function(v)
        if type(v) ~= "table" or #v == 0 then return "wants one number or more" end
        for i, n in ipairs(v) do
            if not is_number(n) then return "item " .. i .. " is not a number" end
        end
    end },
    texts = { doc = "`{\"…\", …}`, strings", check = function(v)
        if type(v) ~= "table" then return "wants a list of strings" end
        for i, s in ipairs(v) do
            if type(s) ~= "string" then return "item " .. i .. " is not text" end
        end
    end },
    category = { doc = "one of the studio's categories: " .. table.concat(wall.CATEGORIES, ", "), check = function(v)
        for _, c in ipairs(wall.CATEGORIES) do
            if v == c then return nil end
        end
        return "wants a category, got " .. describe(v), wall.nearest(v, wall.CATEGORIES)
    end },
    look = { doc = "the look's own fields by name (070): " .. table.concat(the_look.FIELDS, ", "), check = function(v)
        if type(v) ~= "table" then return "wants a table of the look's fields" end
        for _, k in ipairs(sorted_keys(v)) do
            local known = false
            for _, f in ipairs(the_look.FIELDS) do
                if f == k then known = true end
            end
            if not known then
                return "has no look field '" .. tostring(k) .. "'", wall.nearest(k, the_look.FIELDS)
            end
        end
    end },
    boxes = { doc = "`{{name = …, text = …}, …}`, one box or more, each named", check = function(v)
        if type(v) ~= "table" or #v == 0 then return "wants one box or more" end
        for i, b in ipairs(v) do
            if type(b) ~= "table" or type(b.name) ~= "string" or not b.name:match("^%a[%w_%-]*$") then
                return "box " .. i .. " has no name"
            end
        end
    end },
    arrows = { doc = "`{{from = …, to = …, there = …, here = …}, …}`, each naming two boxes", check = function(v)
        if type(v) ~= "table" then return "wants a list of arrows" end
        for i, a in ipairs(v) do
            if type(a) ~= "table" or type(a.from) ~= "string" or type(a.to) ~= "string" then
                return "arrow " .. i .. " needs a from and a to"
            end
        end
    end },
}

-- {{{ local function choice
-- A type that is one of a closed list of words.
local function choice(words)
    return { doc = "one of " .. table.concat(words, ", "), check = function(v)
        for _, w in ipairs(words) do
            if v == w then return nil end
        end
        return "wants one of " .. table.concat(words, ", ") .. ", got " .. describe(v), wall.nearest(v, words)
    end }
end
-- }}}
-- }}}

-- The `.png` end's paintbrush (docs/067's "Each end" row). `ground` is
-- spelled through the look (canvas{ look = { ground = … } }) rather than a
-- word of its own, so the ground has one place.
wall.PNG = {
    name = "png",
    words = {
        canvas = {
            doc = "what the canvas is: its category, size, seed and look", once = true, required = true,
            order = { "category", "width", "height", "seed", "look" },
            fields = {
                category = { type = "category", required = true, doc = "what kind of asset" },
                width = { type = "positive", default = 640, doc = "pixels across" },
                height = { type = "positive", default = 360, doc = "pixels down" },
                seed = { type = "whole", default = 1, doc = "the seed every random choice starts from" },
                look = { type = "look", default = {}, doc = "the look's fields this canvas changes (070); a day palette is refused for a night-only category" },
            },
        },
        line = {
            doc = "a straight line",
            order = { "from", "to", "weight", "colour" },
            fields = {
                from = { type = "point", required = true, doc = "where it starts" },
                to = { type = "point", required = true, doc = "where it ends" },
                weight = { type = "number", default = "look", doc = "pixels wide; the look's line_weight when absent" },
                colour = { type = "colour", default = "ink", doc = "the palette's ink when absent" },
            },
        },
        surface = {
            doc = "a filled polygon; with a name, arrows can point at it",
            order = { "points", "name", "colour", "flair" },
            fields = {
                points = { type = "points", required = true, doc = "its corners, in order" },
                name = { type = "name", doc = "what arrows call it" },
                colour = { type = "colour", default = "ink", doc = "the palette's ink when absent" },
                flair = { type = choice({ "on", "off" }), default = "look", doc = "the flair on its midline; the look's flair when absent" },
            },
        },
        arrow = {
            doc = "a line from one place to another, its head at the far end, a label at either end (there — here)",
            order = { "from", "to", "there", "here", "colour" },
            fields = {
                from = { type = "place", required = true, doc = "where it starts" },
                to = { type = "place", required = true, doc = "where its head is" },
                there = { type = "text", default = "", doc = "the label at its start" },
                here = { type = "text", default = "", doc = "the label at its head" },
                colour = { type = "colour", default = "ink", doc = "the palette's ink when absent" },
            },
        },
        label = {
            doc = "text at a point",
            order = { "text", "at", "size", "colour" },
            fields = {
                text = { type = "text", required = true, doc = "what it says" },
                at = { type = "point", required = true, doc = "its top left" },
                size = { type = "positive", default = 16, doc = "pixels tall" },
                colour = { type = "colour", default = "ink", doc = "the palette's ink when absent" },
            },
        },
        grid = {
            doc = "faint lines across the whole canvas, every `step` pixels",
            order = { "step", "weight" },
            fields = {
                step = { type = "positive", default = 40, doc = "pixels between lines" },
                weight = { type = "number", default = 1, doc = "pixels wide" },
            },
        },
        chart = {
            doc = "a chart over axes (074's geometry)",
            order = { "kind", "data", "labels", "at", "size" },
            fields = {
                kind = { type = choice({ "bars", "lines", "dots" }), default = "bars", doc = "how the data is drawn" },
                data = { type = "numbers", required = true, doc = "the values" },
                labels = { type = "texts", default = {}, doc = "one per value, or none" },
                at = { type = "point", default = { 0, 0 }, doc = "its top left" },
                size = { type = "point", default = "canvas", doc = "its width and height; the whole canvas when absent" },
            },
        },
        diagram = {
            doc = "boxes and arrows laid out by level (134's geometry)",
            order = { "boxes", "arrows" },
            fields = {
                boxes = { type = "boxes", required = true, doc = "the boxes, each named" },
                arrows = { type = "arrows", default = {}, doc = "each from one box to another" },
            },
        },
    },
}

-- {{{ local function type_of
local function type_of(field)
    return type(field.type) == "table" and field.type or wall.TYPES[field.type]
end
-- }}}

-- {{{ local function finding
local function finding(findings, line, word, message, suggestion)
    findings[#findings + 1] = { line = line, word = word, message = message, suggestion = suggestion }
end
-- }}}

-- {{{ function wall.text
-- One finding as one line: "<where>:<line>: <word>: <message>; did you
-- mean '<suggestion>'?".
function wall.text(f, where)
    local out = (where or "canvas") .. ":" .. tostring(f.line or "?") .. ": "
        .. (f.word and (f.word .. ": ") or "") .. f.message
    if f.suggestion then
        out = out .. "; did you mean '" .. f.suggestion .. "'?"
    end
    return out
end
-- }}}

-- The most Lua instructions a canvas may run while loading: a canvas is
-- data, so a loop that runs past this is a mistake, stopped and named.
wall.MOST_INSTRUCTIONS = 1000000

-- {{{ function wall.load
-- Loads a canvas's text (`where` names it) through a paintbrush. Returns
-- the words in canvas order, each { word, line, fields }, and every
-- finding from loading — unknown words, unknown fields, wrong types,
-- missing required fields, a word given twice that may appear once, a
-- global assigned — all together. A syntax error or a canvas that will not
-- run is one finding, naming the parser's or Lua's words.
function wall.load(text, brush, where)
    brush = brush or wall.PNG
    local words, findings, counts = {}, {}, {}
    local word_names = sorted_keys(brush.words)
    if text:sub(1, 1) == "\27" then
        finding(findings, 1, nil, "a canvas is text, not compiled bytecode")
        return words, findings
    end
    local chunk, err = loadstring(text, "=" .. (where or "canvas"))
    if not chunk then
        finding(findings, tonumber(tostring(err):match(":(%d+):")), nil, "does not parse: " .. tostring(err):gsub("^[^:]*:%d+: ", ""))
        return words, findings
    end
    local function caller_line()
        local info = debug.getinfo(3, "l")
        return info and info.currentline or nil
    end
    -- While the canvas runs, strings have no methods (no ("x"):rep(…)); the
    -- wall's own checks need them, so each constructor and lookup puts them
    -- back for its own work and takes them away again before returning.
    local string_meta = getmetatable("")
    local string_index = string_meta.__index
    local function with_strings(fn, ...)
        local was = string_meta.__index
        string_meta.__index = string_index
        local ok, err = pcall(fn, ...)
        string_meta.__index = was
        if not ok then error(err, 0) end
    end
    local env = {}
    for _, name in ipairs(word_names) do
        local spec = brush.words[name]
        local function construct(line, given)
            if type(given) ~= "table" then
                finding(findings, line, name, "is written " .. name .. "{ … }, with its fields in braces")
                return
            end
            counts[name] = (counts[name] or 0) + 1
            if spec.once and counts[name] > 1 then
                finding(findings, line, name, "may appear once; this is the " .. counts[name] .. "th")
            end
            local fields = {}
            local legal = sorted_keys(spec.fields)
            for _, key in ipairs(sorted_keys(given)) do
                if not spec.fields[key] then
                    finding(findings, line, name, "has no field '" .. tostring(key) .. "'", wall.nearest(key, legal))
                end
            end
            for _, key in ipairs(spec.order) do
                local field = spec.fields[key]
                local value = given[key]
                if value == nil then
                    if field.required then
                        finding(findings, line, name, "needs its field '" .. key .. "'")
                    else
                        fields[key] = field.default
                    end
                else
                    local wrong, suggestion = type_of(field).check(value)
                    if wrong then
                        finding(findings, line, name, "'" .. key .. "' " .. wrong, suggestion)
                    else
                        fields[key] = value
                    end
                end
            end
            words[#words + 1] = { word = name, line = line, fields = fields }
        end
        env[name] = function(given)
            with_strings(construct, caller_line(), given)
        end
    end
    setmetatable(env, {
        __index = function(_, key)
            local line = caller_line()
            with_strings(function()
                finding(findings, line, nil, "no word '" .. tostring(key) .. "' in the " .. brush.name .. " paintbrush",
                    wall.nearest(key, word_names))
            end)
            -- Something callable, so the rest of the canvas is still read.
            return function() end
        end,
        __newindex = function(_, key)
            local line = caller_line()
            with_strings(function()
                finding(findings, line, nil, "a canvas is data; it may not set '" .. tostring(key) .. "'")
            end)
        end,
    })
    setfenv(chunk, env)
    -- A canvas runs with the string library out of reach (no ("x"):rep(…))
    -- and a ceiling on how much it may run; the JIT is off for it, since a
    -- count hook does not fire inside compiled loops.
    string_meta.__index = nil
    jit.off(chunk, true)
    debug.sethook(function() error("ran past " .. wall.MOST_INSTRUCTIONS .. " instructions", 2) end, "", wall.MOST_INSTRUCTIONS)
    local ok, run_err = pcall(chunk)
    debug.sethook()
    string_meta.__index = string_index
    if not ok then
        finding(findings, tonumber(tostring(run_err):match(":(%d+):")), nil,
            "does not run: " .. tostring(run_err):gsub("^[^:]*:%d+: ", ""))
    end
    for _, name in ipairs(word_names) do
        if brush.words[name].required and not counts[name] then
            local why = name == "canvas" and "every canvas needs one canvas{ … } saying its category"
                or ("every " .. brush.name .. " canvas needs one " .. name .. "{ … }")
            finding(findings, 1, name, why)
        end
    end
    return words, findings
end
-- }}}

-- {{{ local function centre
local function centre(points)
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(points) do
        min_x, max_x = math.min(min_x, p[1]), math.max(max_x, p[1])
        min_y, max_y = math.min(min_y, p[2]), math.max(max_y, p[2])
    end
    return (min_x + max_x) / 2, (min_y + max_y) / 2
end
-- }}}

-- {{{ local function new_arrays
local function new_arrays(names)
    local t = { n = 0 }
    for _, name in ipairs(names) do
        t[name] = {}
    end
    return t
end
-- }}}

-- {{{ function wall.compile
-- Words (load's) into flat parallel arrays, every name resolved to a
-- number once. Returns the compiled canvas and every finding of this pass:
-- a name given twice, a reference to no name, a diagram's arrow to no box,
-- a look the canvas's category refuses. A reference that fails is a
-- finding, never a crash, and leaves its index 0.
--   canvas    { category, width, height, seed }
--   look      the canvas's whole look (070's for_canvas)
--   names     { [name] = surface index }
--   order     { {kind, index}, … } in canvas order, for the painter
--   lines     { n, x1, y1, x2, y2, weight, colour }
--   surfaces  { n, name, first, count, colour, flair }, points in xs, ys
--   arrows    { n, x1, y1, x2, y2, from, to, there, here, colour }
--   labels    { n, text, x, y, size, colour }
--   grids     { n, step, weight }
--   charts    { n, kind, data, labels, x, y, w, h }
--   diagrams  { n, boxes, arrows }
function wall.compile(words)
    local findings = {}
    local c = {
        canvas = { category = "still", width = 640, height = 360, seed = 1 },
        names = {}, order = {}, xs = {}, ys = {},
        lines = new_arrays({ "x1", "y1", "x2", "y2", "weight", "colour" }),
        surfaces = new_arrays({ "name", "first", "count", "colour", "flair" }),
        arrows = new_arrays({ "x1", "y1", "x2", "y2", "from", "to", "there", "here", "colour" }),
        labels = new_arrays({ "text", "x", "y", "size", "colour" }),
        grids = new_arrays({ "step", "weight" }),
        charts = new_arrays({ "kind", "data", "labels", "x", "y", "w", "h" }),
        diagrams = new_arrays({ "boxes", "arrows" }),
    }
    local look_overrides = {}
    for _, w in ipairs(words) do
        if w.word == "canvas" then
            for _, k in ipairs({ "category", "width", "height", "seed" }) do
                if w.fields[k] ~= nil then c.canvas[k] = w.fields[k] end
            end
            look_overrides = w.fields.look or {}
        end
    end
    local ok, look = pcall(the_look.for_canvas, c.canvas.category, look_overrides)
    if not ok then
        local line
        for _, w in ipairs(words) do
            if w.word == "canvas" then line = w.line end
        end
        finding(findings, line, "canvas", "its look is refused: " .. tostring(look):gsub("^[^:]*:%d+: ", ""))
        look = the_look.defaults()
    end
    c.look = look
    local ink = look.palette == "day" and { 20, 20, 20 } or { 235, 235, 235 }
    local function colour_of(v)
        return v == "ink" and ink or v
    end
    local function put(arrays, values)
        arrays.n = arrays.n + 1
        for k, v in pairs(values) do
            arrays[k][arrays.n] = v
        end
        return arrays.n
    end
    -- Names first, so an arrow may point at a surface named after it.
    for _, w in ipairs(words) do
        if w.word == "surface" and w.fields.name then
            if c.names[w.fields.name] then
                finding(findings, w.line, "surface", "the name '" .. w.fields.name .. "' is given twice")
            else
                c.names[w.fields.name] = -1
            end
        end
    end
    local surface_points = {}
    for _, w in ipairs(words) do
        local f = w.fields
        if w.word == "line" and f.from and f.to then
            local i = put(c.lines, { x1 = f.from[1], y1 = f.from[2], x2 = f.to[1], y2 = f.to[2],
                weight = f.weight == "look" and look.line_weight or f.weight, colour = colour_of(f.colour) })
            c.order[#c.order + 1] = { "line", i }
        elseif w.word == "surface" and f.points then
            local first = #c.xs + 1
            for _, p in ipairs(f.points) do
                c.xs[#c.xs + 1], c.ys[#c.ys + 1] = p[1], p[2]
            end
            local flair = f.flair == "look" and (look.flair and "on" or "off") or f.flair
            local i = put(c.surfaces, { name = f.name or "", first = first, count = #f.points,
                colour = colour_of(f.colour), flair = flair })
            surface_points[i] = f.points
            if f.name and c.names[f.name] == -1 then c.names[f.name] = i end
            c.order[#c.order + 1] = { "surface", i }
        elseif w.word == "label" and f.text and f.at then
            local i = put(c.labels, { text = f.text, x = f.at[1], y = f.at[2], size = f.size, colour = colour_of(f.colour) })
            c.order[#c.order + 1] = { "label", i }
        elseif w.word == "grid" then
            local i = put(c.grids, { step = f.step, weight = f.weight })
            c.order[#c.order + 1] = { "grid", i }
        elseif w.word == "chart" and f.data then
            if #f.labels > 0 and #f.labels ~= #f.data then
                finding(findings, w.line, "chart", #f.labels .. " labels for " .. #f.data .. " values")
            end
            local size = f.size == "canvas" and { c.canvas.width, c.canvas.height } or f.size
            local i = put(c.charts, { kind = f.kind, data = f.data, labels = f.labels,
                x = f.at[1], y = f.at[2], w = size[1], h = size[2] })
            c.order[#c.order + 1] = { "chart", i }
        elseif w.word == "diagram" and f.boxes then
            local known, names = {}, {}
            for _, b in ipairs(f.boxes) do
                if known[b.name] then
                    finding(findings, w.line, "diagram", "the box '" .. b.name .. "' is named twice")
                end
                known[b.name] = true
                names[#names + 1] = b.name
            end
            for i, a in ipairs(f.arrows) do
                for _, which in ipairs({ "from", "to" }) do
                    if not known[a[which]] then
                        finding(findings, w.line, "diagram", "arrow " .. i .. "'s " .. which .. " '" .. tostring(a[which])
                            .. "' is no box", wall.nearest(a[which], names))
                    end
                end
            end
            local i = put(c.diagrams, { boxes = f.boxes, arrows = f.arrows })
            c.order[#c.order + 1] = { "diagram", i }
        end
    end
    local surface_names = sorted_keys(c.names)
    for _, w in ipairs(words) do
        local f = w.fields
        if w.word == "arrow" and f.from and f.to then
            local ends, indices = {}, {}
            for _, which in ipairs({ "from", "to" }) do
                local place = f[which]
                if type(place) == "string" then
                    local index = c.names[place]
                    if not index or index < 1 then
                        finding(findings, w.line, "arrow", "'" .. which .. "' names '" .. place .. "', and no surface has that name",
                            wall.nearest(place, surface_names))
                        ends[which], indices[which] = { 0, 0 }, 0
                    else
                        ends[which], indices[which] = { centre(surface_points[index]) }, index
                    end
                else
                    ends[which], indices[which] = place, 0
                end
            end
            local i = put(c.arrows, { x1 = ends.from[1], y1 = ends.from[2], x2 = ends.to[1], y2 = ends.to[2],
                from = indices.from, to = indices.to, there = f.there, here = f.here, colour = colour_of(f.colour) })
            c.order[#c.order + 1] = { "arrow", i }
        end
    end
    -- Arrows are drawn after everything else, so a head is never covered.
    return c, findings
end
-- }}}

-- {{{ function wall.read
-- Load and compile one canvas's text in one run: the compiled canvas, or
-- nil and every finding of both passes, in line order.
function wall.read(text, brush, where)
    local words, findings = wall.load(text, brush, where)
    local compiled, more = wall.compile(words)
    for _, f in ipairs(more) do
        findings[#findings + 1] = f
    end
    if #findings > 0 then
        for i, f in ipairs(findings) do
            f.order = i
        end
        table.sort(findings, function(a, b)
            if (a.line or 0) ~= (b.line or 0) then return (a.line or 0) < (b.line or 0) end
            return a.order < b.order
        end)
        return nil, findings
    end
    return compiled
end
-- }}}

-- {{{ function wall.read_file
function wall.read_file(path, brush)
    local file = io.open(path, "rb")
    if not file then
        error("wall.read_file: cannot open " .. path)
    end
    local text = file:read("*a")
    file:close()
    return wall.read(text, brush, path:match("[^/]+$"))
end
-- }}}

-- {{{ local function show_default
local function show_default(field)
    local d = field.default
    if field.required then return "required" end
    if d == "look" then return "from the look" end
    if d == "ink" then return "the palette's ink" end
    if d == "canvas" then return "the canvas's size" end
    if d == "last" then return "the last frame" end
    if type(d) == "table" then
        local parts = {}
        for _, v in ipairs(d) do parts[#parts + 1] = tostring(v) end
        return "`{" .. table.concat(parts, ", ") .. "}`"
    end
    if d == nil then return "none" end
    if type(d) == "string" then return "`\"" .. d .. "\"`" end
    return "`" .. tostring(d) .. "`"
end
-- }}}

-- {{{ function wall.document
-- The paintbrush's document, generated from its own table: every word, in
-- name order, with every field, its type and its default — the one place
-- a canvas author reads, which cannot drift from what the wall enforces.
function wall.document(brush)
    brush = brush or wall.PNG
    local lines = {
        "# The " .. brush.name .. " paintbrush",
        "",
        "Generated from `" .. (brush.source or "src/151-the-wall.lua") .. "`'s `" .. brush.name:upper() .. "` table by",
        "`wall.document()`; do not edit by hand (a check compares the two).",
        "A canvas is a Lua file of these words and nothing else; a word or",
        "field not here is refused, with the nearest legal one named.",
    }
    for _, name in ipairs(sorted_keys(brush.words)) do
        local spec = brush.words[name]
        lines[#lines + 1] = ""
        lines[#lines + 1] = "## `" .. name .. "{ … }`"
        lines[#lines + 1] = ""
        lines[#lines + 1] = spec.doc:gsub("^%l", string.upper) .. "." .. (spec.required and " Every canvas has exactly one." or (spec.once and " At most one." or ""))
        lines[#lines + 1] = ""
        lines[#lines + 1] = "| Field | Type | Default | Meaning |"
        lines[#lines + 1] = "|---|---|---|---|"
        for _, key in ipairs(spec.order) do
            local field = spec.fields[key]
            lines[#lines + 1] = string.format("| `%s` | %s | %s | %s |", key, type_of(field).doc, show_default(field), field.doc)
        end
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

wall.distance = distance

return wall
