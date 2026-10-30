-- 045-scene-file.lua — a shape scene as a file: read in a sandbox,
-- written as canonical text.
--
-- What this is, generally: a 3D scene is data, not a program (issue
-- 701c), as a 2D score is. Reading one runs the file with nothing in
-- reach: no math, no loops' helpers, no files, no other scenes. A scene
-- that needs to compute (a ring of blobs, a wizard reused) is written as
-- a generator instead, an ordinary Lua program in input/shapes/generators/
-- whose returned table this module writes out as the plain scene beside
-- the others. The scene stays data; the generation stays visible.
--
-- Data-format notes worth knowing more than once:
--   * written numbers round-trip exactly: the shortest of %.15g, %.16g,
--     %.17g that reads back as the same double, so a generated scene
--     films the same bytes as the program it came from.
--   * keys are written in a fixed order (the array part first, in order,
--     then names sorted), so writing the same table twice gives the same
--     text, and a stale generated scene shows up as a difference.
--   * a table met twice (a part shared between two wizards) is written
--     out twice. Scenes are trees on the page.

local scene_file = {}

-- {{{ function scene_file.read()
-- Run a scene file in an empty sandbox; return its table. A scene that
-- reaches for anything (math, ipairs, dofile, debug) is refused, with
-- the way out named.
function scene_file.read(path)
    local chunk, load_err = loadfile(path)
    if not chunk then
        error("scene: cannot read '" .. path .. "': " .. tostring(load_err), 0)
    end
    setfenv(chunk, {})
    local ok, result = pcall(chunk)
    if not ok then
        error("scene: '" .. path .. "' failed while declaring -- scenes "
              .. "declare, they never compute; a scene that needs a loop or "
              .. "math is written as a generator in input/shapes/generators/ "
              .. "(then ./make-shapes): " .. tostring(result), 0)
    end
    if type(result) ~= "table" then
        error("scene: '" .. path .. "' returns " .. type(result)
              .. ", not a scene table", 0)
    end
    return result
end
-- }}}

-- {{{ local function number_text()
-- The shortest text that reads back as exactly this double.
local function number_text(n)
    if n ~= n or n == math.huge or n == -math.huge then
        error("scene writer: " .. tostring(n) .. " cannot be written as a scene number", 0)
    end
    if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
        return string.format("%d", n)
    end
    for _, form in ipairs({ "%.15g", "%.16g", "%.17g" }) do
        local text = string.format(form, n)
        if tonumber(text) == n then return text end
    end
    return string.format("%.17g", n)
end
-- }}}

-- {{{ local function key_text()
-- A name key bare when Lua allows it, bracketed otherwise.
local RESERVED = {}
for word in ("and break do else elseif end false for function goto if in "
             .. "local nil not or repeat return then true until while"):gmatch("%a+") do
    RESERVED[word] = true
end
local function key_text(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") and not RESERVED[k] then
        return k
    elseif type(k) == "string" then
        return "[" .. string.format("%q", k) .. "]"
    end
    return "[" .. number_text(k) .. "]"
end
-- }}}

-- {{{ local function ordered_keys()
-- The array part 1..n in order, then every other key sorted (numbers
-- before strings, each in its natural order).
local function ordered_keys(t)
    local n = #t
    local rest = {}
    for k in pairs(t) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
            rest[#rest + 1] = k
        end
    end
    table.sort(rest, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return n, rest
end
-- }}}

-- {{{ local function is_flat()
-- A short list of plain values (a point, a colour, a list of hue names)
-- is written on one line.
local function is_flat(t)
    local n, rest = ordered_keys(t)
    if #rest > 0 or n > 8 then return false end
    for i = 1, n do
        local kind = type(t[i])
        if kind ~= "number" and kind ~= "string" and kind ~= "boolean" then return false end
    end
    return true
end
-- }}}

-- {{{ local function value_text()
local function value_text(v, indent, out)
    local kind = type(v)
    if kind == "number" then
        out[#out + 1] = number_text(v)
    elseif kind == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif kind == "boolean" then
        out[#out + 1] = tostring(v)
    elseif kind == "table" then
        local n, rest = ordered_keys(v)
        if n == 0 and #rest == 0 then
            out[#out + 1] = "{}"
        elseif is_flat(v) then
            local items = {}
            for i = 1, n do
                local piece = {}
                value_text(v[i], indent, piece)
                items[i] = table.concat(piece)
            end
            out[#out + 1] = "{ " .. table.concat(items, ", ") .. " }"
        else
            local inner = indent .. "    "
            out[#out + 1] = "{\n"
            for i = 1, n do
                out[#out + 1] = inner
                value_text(v[i], inner, out)
                out[#out + 1] = ",\n"
            end
            for _, k in ipairs(rest) do
                out[#out + 1] = inner .. key_text(k) .. " = "
                value_text(v[k], inner, out)
                out[#out + 1] = ",\n"
            end
            out[#out + 1] = indent .. "}"
        end
    else
        error("scene writer: a " .. kind .. " cannot be written into a scene", 0)
    end
end
-- }}}

-- {{{ function scene_file.value_text()
-- One value as canonical scene text (the shape{} and camera{} calls of a
-- two-space score are written with it, so their numbers round-trip too).
function scene_file.value_text(v, indent)
    local out = {}
    value_text(v, indent or "", out)
    return table.concat(out)
end
-- }}}

-- {{{ function scene_file.write()
-- The canonical text of a scene table, `header` (comment lines, already
-- prefixed with --) above it.
function scene_file.write(scene, header)
    local out = {}
    if header and header ~= "" then out[#out + 1] = header .. "\n" end
    out[#out + 1] = "return "
    value_text(scene, "", out)
    out[#out + 1] = "\n"
    return table.concat(out)
end
-- }}}

return scene_file
