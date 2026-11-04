-- see-in-3d-paintbrush.lua - Reads a scene file, refuses it loudly if it says
-- anything the paintbrush does not allow, and turns what it does say into
-- triangles.
--
-- In plain terms: a scene is a few lines naming shapes -- a box here, a ball
-- there -- with where they sit and what colour they are. This runs the scene
-- file as Lua in a room holding only those words (scene, box, sphere,
-- cylinder, cone), so Lua itself is the reader and its syntax errors come
-- with line numbers for free. Then the wall: every shape's fields checked,
-- every problem gathered in one pass and reported together, each with the
-- nearest legal word (a misspelt "colour" is told "color"). Nothing is filled
-- in except the three defaults the paintbrush document publishes (at, turn,
-- color). Last, each shape becomes triangles, with every name and turn
-- resolved here, once, so the renderer only ever sees numbers.
--
-- The contract is see-in-3d-paintbrush.md beside the command; the table
-- `shapes` below is its executable half and must say the same thing.

local M = {}

-- {{{ shapes
-- Each legal shape word: its required size fields and how it becomes
-- triangles. A table, so a new shape is one entry here and one row in the
-- document.
local SEGMENTS = 24
local shapes = {}
M.shapes = shapes
-- }}}

-- {{{ M.common_fields / defaults
-- Fields every shape takes, with the published defaults.
M.common_fields = { name = true, at = true, turn = true, color = true, glow = true }
M.defaults = { at = { 0, 0, 0 }, turn = { 0, 0, 0 }, color = "#b0b0b0", glow = false }
-- }}}

-- {{{ local function distance()
-- Edit distance between two words: how many single-letter changes turn one
-- into the other. Used to find the legal word nearest an illegal one.
local function distance(a, b)
    local previous = {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        local current = { [0] = i }
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end
-- }}}

-- {{{ local function nearest()
local function nearest(word, legal)
    local best, best_distance = nil, math.huge
    local sorted = {}
    for candidate in pairs(legal) do sorted[#sorted + 1] = candidate end
    table.sort(sorted)
    for _, candidate in ipairs(sorted) do
        local d = distance(word:lower(), candidate)
        if d < best_distance then best, best_distance = candidate, d end
    end
    return best
end
-- }}}

-- {{{ local function triangle()
-- Appends one triangle to the model's flat arrays: nine coordinates in the
-- vertex arrays, one colour in the colour arrays.
local function triangle(model, a, b, c, color)
    local px, py, pz = model.px, model.py, model.pz
    local n = #px
    px[n + 1], py[n + 1], pz[n + 1] = a[1], a[2], a[3]
    px[n + 2], py[n + 2], pz[n + 2] = b[1], b[2], b[3]
    px[n + 3], py[n + 3], pz[n + 3] = c[1], c[2], c[3]
    local t = #model.cr + 1
    model.cr[t], model.cg[t], model.cb[t] = color[1], color[2], color[3]
end
-- }}}

-- {{{ local function placer()
-- A function taking a point in the shape's own space to the scene: turned
-- about x, then y, then z (degrees), then moved to `at`. Sines and cosines are
-- worked out once per shape, not once per point.
local function placer(at, turn)
    local rx, ry, rz = math.rad(turn[1]), math.rad(turn[2]), math.rad(turn[3])
    local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    return function(x, y, z)
        y, z = y * cx - z * sx, y * sx + z * cx
        x, z = x * cy + z * sy, -x * sy + z * cy
        x, y = x * cz - y * sz, x * sz + y * cz
        return { x + at[1], y + at[2], z + at[3] }
    end
end
-- }}}

-- {{{ shapes.box
shapes.box = {
    required = { size = "triple" },
    build = function(model, spec, place, color)
        local w, h, d = spec.size[1] / 2, spec.size[2] / 2, spec.size[3] / 2
        local corner = {}
        for i = 0, 7 do
            corner[i] = place((i % 2 == 0) and -w or w, (math.floor(i / 2) % 2 == 0) and -h or h, (i < 4) and -d or d)
        end
        -- six faces, each two triangles, corners listed counter-clockwise from outside
        local faces = { { 0, 2, 3, 1 }, { 4, 5, 7, 6 }, { 0, 1, 5, 4 }, { 2, 6, 7, 3 }, { 0, 4, 6, 2 }, { 1, 3, 7, 5 } }
        for _, f in ipairs(faces) do
            triangle(model, corner[f[1]], corner[f[2]], corner[f[3]], color)
            triangle(model, corner[f[1]], corner[f[3]], corner[f[4]], color)
        end
    end,
}
-- }}}

-- {{{ shapes.sphere
shapes.sphere = {
    required = { radius = "positive" },
    build = function(model, spec, place, color)
        local r, rings = spec.radius, SEGMENTS / 2
        local function point(ring, step)
            local polar = math.pi * ring / rings
            local around = 2 * math.pi * step / SEGMENTS
            return place(r * math.sin(polar) * math.cos(around), r * math.cos(polar), r * math.sin(polar) * math.sin(around))
        end
        for ring = 0, rings - 1 do
            for step = 0, SEGMENTS - 1 do
                local a, b = point(ring, step), point(ring, step + 1)
                local c, d = point(ring + 1, step + 1), point(ring + 1, step)
                if ring > 0 then triangle(model, a, b, c, color) end
                if ring < rings - 1 then triangle(model, a, c, d, color) end
            end
        end
    end,
}
-- }}}

-- {{{ local function round_shape()
-- A cylinder and a cone are the same ring of side panels with a different
-- top radius (the cone's is zero); caps close the ends that have a radius.
local function round_shape(model, spec, place, color, top_radius)
    local r, half = spec.radius, spec.height / 2
    local function rim(step, radius, y)
        local around = 2 * math.pi * step / SEGMENTS
        return place(radius * math.cos(around), y, radius * math.sin(around))
    end
    local bottom_centre, top_centre = place(0, -half, 0), place(0, half, 0)
    for step = 0, SEGMENTS - 1 do
        local b0, b1 = rim(step, r, -half), rim(step + 1, r, -half)
        local t0, t1 = rim(step, top_radius, half), rim(step + 1, top_radius, half)
        triangle(model, b0, t1, b1, color)
        if top_radius > 0 then
            triangle(model, b0, t0, t1, color)
            triangle(model, top_centre, t1, t0, color)
        end
        triangle(model, bottom_centre, b0, b1, color)
    end
end
-- }}}

-- {{{ shapes.cylinder / shapes.cone
shapes.cylinder = {
    required = { radius = "positive", height = "positive" },
    build = function(model, spec, place, color) round_shape(model, spec, place, color, spec.radius) end,
}
shapes.cone = {
    required = { radius = "positive", height = "positive" },
    build = function(model, spec, place, color) round_shape(model, spec, place, color, 0) end,
}
-- }}}

-- {{{ local checks
-- What each kind of field must hold; each returns nil when fine, or what is wrong.
local function is_number(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local checks = {
    positive = function(v) if not is_number(v) or v <= 0 then return "must be a number above zero" end end,
    triple = function(v)
        if type(v) ~= "table" or #v ~= 3 or not (is_number(v[1]) and is_number(v[2]) and is_number(v[3])) then
            return "must be three numbers, like {1, 2, 3}"
        end
    end,
    positive_triple = function(v)
        if type(v) ~= "table" or #v ~= 3 then return "must be three numbers above zero, like {1, 2, 3}" end
        for i = 1, 3 do if not is_number(v[i]) or v[i] <= 0 then return "must be three numbers above zero, like {1, 2, 3}" end end
    end,
    color = function(v) if type(v) ~= "string" or not v:match("^#%x%x%x%x%x%x$") then return 'must be "#rrggbb", like "#cc3333"' end end,
    text = function(v) if type(v) ~= "string" then return "must be text in quotes" end end,
    flag = function(v) if type(v) ~= "boolean" then return "must be true or false" end end,
}
shapes.box.required.size = "positive_triple"
local common_kinds = { name = "text", at = "triple", turn = "triple", color = "color", glow = "flag" }
-- }}}

-- {{{ M.read(path)
-- A scene file, read and checked. Returns the scene { what, shapes = list of
-- { kind, line, fields } }, or nil and a list of problem strings (all of
-- them, in file order).
function M.read(path)
    local problems, calls, scene_calls = {}, {}, {}
    local env = {}
    -- each legal word records its call and the line it was made on
    for kind in pairs(shapes) do
        env[kind] = function(fields)
            calls[#calls + 1] = { kind = kind, line = debug.getinfo(2, "l").currentline, fields = fields }
        end
    end
    env.scene = function(fields)
        scene_calls[#scene_calls + 1] = { line = debug.getinfo(2, "l").currentline, fields = fields }
    end
    local legal_words = { scene = true }
    for kind in pairs(shapes) do legal_words[kind] = true end
    -- any other word is recorded as a problem and swallowed, so the rest of
    -- the file still runs and every problem is found in one pass
    setmetatable(env, { __index = function(_, word)
        problems[#problems + 1] = string.format("line %d: \"%s\" is not a paintbrush word (nearest: %s)",
            debug.getinfo(2, "l").currentline or 0, word, nearest(word, legal_words))
        return function() end
    end })

    local chunk, syntax = loadfile(path)
    if not chunk then return nil, { "the scene file cannot be read as Lua: " .. tostring(syntax) } end
    setfenv(chunk, env)
    local ran, runtime = pcall(chunk)
    if not ran then problems[#problems + 1] = "the scene file stopped: " .. tostring(runtime) end

    -- the scene line: exactly one, with a what
    if #scene_calls ~= 1 then
        problems[#problems + 1] = string.format("there must be exactly one scene{what = \"...\"}; found %d", #scene_calls)
    end
    local what = ""
    for _, call in ipairs(scene_calls) do
        if type(call.fields) ~= "table" or type(call.fields.what) ~= "string" then
            problems[#problems + 1] = string.format("line %d: scene needs what = \"one line saying what this shows\"", call.line)
        else
            what = call.fields.what
            for field in pairs(call.fields) do
                if field ~= "what" then
                    problems[#problems + 1] = string.format("line %d: scene has no field \"%s\" (nearest: what)", call.line, tostring(field))
                end
            end
        end
    end
    if #calls == 0 then problems[#problems + 1] = "the scene has no shapes" end

    -- every shape: its fields known, its required fields present, each well formed
    for number, call in ipairs(calls) do
        local spec = shapes[call.kind]
        local fields = call.fields
        local label = string.format("line %d, %s %d", call.line, call.kind, number)
        if type(fields) ~= "table" then
            problems[#problems + 1] = label .. ": fields go in braces, like " .. call.kind .. "{ ... }"
        else
            if type(fields.name) == "string" then label = label .. " \"" .. fields.name .. "\"" end
            local legal = {}
            for field in pairs(M.common_fields) do legal[field] = true end
            for field in pairs(spec.required) do legal[field] = true end
            for field, value in pairs(fields) do
                if not legal[field] then
                    problems[#problems + 1] = string.format("%s: no field \"%s\" (nearest: %s)", label, tostring(field), nearest(tostring(field), legal))
                else
                    local kind = spec.required[field] or common_kinds[field]
                    local wrong = checks[kind](value)
                    if wrong then problems[#problems + 1] = string.format("%s: %s %s", label, field, wrong) end
                end
            end
            for field in pairs(spec.required) do
                if fields[field] == nil then problems[#problems + 1] = string.format("%s: needs %s", label, field) end
            end
        end
    end
    if #problems > 0 then return nil, problems end
    return { what = what, shapes = calls }
end
-- }}}

-- {{{ M.compile(scene)
-- The scene as triangles in flat arrays: px, py, pz (three entries per
-- triangle), cr, cg, cb (one colour per triangle, 0..1), glow (one boolean per
-- triangle: true means it gives off its own light and is drawn unshaded), and parts (one entry
-- per shape: its name and the range of its triangles, for the .obj file).
-- Defaults are applied here and only here, from M.defaults.
function M.compile(scene)
    local model = { what = scene.what, px = {}, py = {}, pz = {}, cr = {}, cg = {}, cb = {}, glow = {}, parts = {} }
    for number, call in ipairs(scene.shapes) do
        local fields = call.fields
        local at = fields.at or M.defaults.at
        local turn = fields.turn or M.defaults.turn
        local hex = fields.color or M.defaults.color
        local color = { tonumber(hex:sub(2, 3), 16) / 255, tonumber(hex:sub(4, 5), 16) / 255, tonumber(hex:sub(6, 7), 16) / 255 }
        local first = #model.cr + 1
        shapes[call.kind].build(model, fields, placer(at, turn), color)
        local glows = fields.glow
        if glows == nil then glows = M.defaults.glow end
        for t = first, #model.cr do model.glow[t] = glows end
        model.parts[#model.parts + 1] = { name = fields.name or (call.kind .. "-" .. number), first = first, last = #model.cr, color = hex }
    end
    return model
end
-- }}}

-- {{{ M.write_obj(model, path)
-- The model as a Wavefront .obj file (text): every triangle's three corners
-- as vertices and one face each, grouped by shape. Any 3D viewer opens it.
function M.write_obj(model, path)
    local handle = io.open(path, "w")
    if not handle then error("see-in-3d: cannot write " .. path, 0) end
    handle:write("# Made by scripts/see-in-3d from a scene description: ", model.what, "\n")
    local vertex = 0
    for _, part in ipairs(model.parts) do
        handle:write("o ", (part.name:gsub("%s", "_")), "\n")
        for t = part.first, part.last do
            for corner = 0, 2 do
                local i = (t - 1) * 3 + corner + 1
                handle:write(string.format("v %.5f %.5f %.5f\n", model.px[i], model.py[i], model.pz[i]))
            end
            handle:write(string.format("f %d %d %d\n", vertex + 1, vertex + 2, vertex + 3))
            vertex = vertex + 3
        end
    end
    handle:close()
end
-- }}}

return M
