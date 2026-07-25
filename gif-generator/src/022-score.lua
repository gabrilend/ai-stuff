-- 022-score.lua — the score reader, the vocabulary constructors, the
-- walk-back insertion, and the canonical writer.
--
-- What this is, generally: scores are Lua files run inside a sandbox
-- that offers exactly the vocabulary (canvas, stroke, arc, line,
-- point, fill, tip) and nothing else — they declare, they never
-- compute. Reading a score yields a plain table of raw declarations;
-- the compiler's wall (next module) does ALL deep checking, so that
-- every mistake in a score is reported together, not one per run.
-- Writing a score emits canonical text: strokes sorted by time via
-- the walk-back insertion, comments carried above the strokes they
-- describe.
--
-- Data-format notes worth knowing more than once:
--   * constructors are dumb taggers: arc{...} returns its table with
--     kind = "arc". Deep validation belongs to the wall alone.
--   * tip("name") returns { ref = "tip", of = "name" } — a landmark
--     borrowing, resolved to coordinates at compile time.
--   * the insertion keeps equal-time strokes in arrival order
--     (stable), because emission order is the random stream's order
--     and determinism is a promise.

local score = {}

-- {{{ local function tagger()
-- Builds a constructor that stamps a kind onto its table. The stamp
-- is a plain field, so a hand-built table with the right kind would
-- also pass — scores are data, not identities.
local function tagger(kind)
    return function(t)
        if type(t) ~= "table" then
            error("score: " .. kind .. "{...} wants a table, got "
                  .. type(t), 2)
        end
        t.kind = kind
        return t
    end
end
-- }}}

-- {{{ function score.read()
-- Run a score file in the sandbox; return { canvas, strokes }.
-- Structural refusals live here (no canvas, two canvases, no
-- strokes, computing); everything field-level waits for the wall.
function score.read(path)
    local chunk, load_err = loadfile(path)
    if not chunk then
        error("score: cannot read '" .. path .. "': "
              .. tostring(load_err))
    end

    local raw = { canvas = nil, strokes = {} }
    local env = {
        arc = tagger("arc"),
        line = tagger("line"),
        point = tagger("point"),
        fill = tagger("fill"),
        -- {{{ tip()
        tip = function(name)
            return { ref = "tip", of = name }
        end,
        -- }}}
        -- {{{ canvas()
        canvas = function(t)
            if raw.canvas then
                error("score: two canvas calls — a score has one "
                      .. "canvas; the second one is a mistake or a "
                      .. "second score", 2)
            end
            raw.canvas = t
        end,
        -- }}}
        -- {{{ stroke()
        stroke = function(t)
            raw.strokes[#raw.strokes + 1] = t
        end,
        -- }}}
    }
    setfenv(chunk, env)
    local ok, run_err = pcall(chunk)
    if not ok then
        error("score: '" .. path .. "' failed while declaring — "
              .. "scores declare, they never compute: "
              .. tostring(run_err))
    end
    if not raw.canvas then
        error("score: '" .. path .. "' never called canvas{...} — "
              .. "a score begins by naming its stage")
    end
    if #raw.strokes == 0 then
        error("score: '" .. path .. "' has no strokes — an empty "
              .. "stage is not a picture")
    end
    return raw
end
-- }}}

-- {{{ function score.insert()
-- The walk-back insertion, in gabrilend's founding words: keep an
-- index into the array; decrement it until the comparison is a
-- no-op instead of a GOTO-and-do. Place the newcomer at the end,
-- walk it up past everything that starts later, stop at the first
-- entry that does not (equal times stop the walk — arrival order
-- kept, determinism kept).
function score.insert(list, stroke)
    local i = #list + 1
    list[i] = stroke
    while i > 1 and list[i - 1].at > stroke.at do
        list[i] = list[i - 1]
        i = i - 1
        list[i] = stroke
    end
end
-- }}}

-- {{{ local function fmt_number()
-- Numbers in canonical text: integers bare, fractions with just
-- enough digits (%.10g trims trailing zeros).
local function fmt_number(n)
    if n == math.floor(n) then
        return string.format("%d", n)
    end
    return string.format("%.10g", n)
end
-- }}}

-- {{{ local function fmt_value()
-- One field value as score text: numbers, strings, point pairs,
-- tip refs, shapes, and flat option tables.
local function fmt_value(v)
    if type(v) == "number" then
        return fmt_number(v)
    end
    if type(v) == "string" then
        return string.format("%q", v)
    end
    if type(v) == "table" then
        if v.ref == "tip" then
            return "tip(" .. string.format("%q", v.of) .. ")"
        end
        if v.kind then
            return score.fmt_shape(v)
        end
        -- a bare table is either a point pair {x, y} or a flat
        -- option block; array part first, then sorted named fields
        local parts = {}
        for _, item in ipairs(v) do
            parts[#parts + 1] = fmt_value(item)
        end
        local names = {}
        for k in pairs(v) do
            if type(k) == "string" then names[#names + 1] = k end
        end
        table.sort(names)
        for _, k in ipairs(names) do
            parts[#parts + 1] = k .. " = " .. fmt_value(v[k])
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    error("score: cannot write a " .. type(v) .. " into a score")
end
-- }}}

-- {{{ function score.fmt_shape()
-- A shape back into constructor syntax, fields in a fixed order so
-- two writes of one score are byte-identical.
local SHAPE_FIELDS = {
    arc = { "center", "radius", "from", "to", "turn" },
    line = { "from", "to" },
    point = { "at" },
    fill = { "vertices", "sweep" },
}
function score.fmt_shape(shape)
    local order = SHAPE_FIELDS[shape.kind]
    if not order then
        error("score: cannot write unknown shape kind '"
              .. tostring(shape.kind) .. "'")
    end
    local parts = {}
    for _, field in ipairs(order) do
        if shape[field] ~= nil then
            parts[#parts + 1] = field .. " = " .. fmt_value(shape[field])
        end
    end
    return shape.kind .. "{ " .. table.concat(parts, ", ") .. " }"
end
-- }}}

-- {{{ function score.write()
-- The canonical text of a score table: canvas first, then strokes
-- sorted by the walk-back insertion, each with its comment (the
-- porch carries prose sentences here) above it. Returns the text;
-- callers land it on disk.
local STROKE_FIELDS = { "name", "at", "lasts", "color", "fade",
                        "ease", "shape", "emit" }
function score.write(raw)
    local lines = {}
    -- {{{ local function put()
    local function put(s) lines[#lines + 1] = s end
    -- }}}

    local cv = raw.canvas
    local head = "canvas{ size = " .. fmt_number(cv.size)
                 .. ", fps = " .. fmt_number(cv.fps)
                 .. ", length = " .. fmt_number(cv.length)
                 .. ", seed = " .. fmt_number(cv.seed)
    if cv.gravity then
        head = head .. ", gravity = " .. fmt_value(cv.gravity)
    end
    put(head .. " }")
    put("")

    local sorted = {}
    for _, s in ipairs(raw.strokes) do
        score.insert(sorted, s)
    end
    for _, s in ipairs(sorted) do
        if s.comment then
            for line in tostring(s.comment):gmatch("[^\n]+") do
                put("-- " .. line)
            end
        end
        local parts = {}
        for _, field in ipairs(STROKE_FIELDS) do
            if s[field] ~= nil then
                parts[#parts + 1] = field .. " = " .. fmt_value(s[field])
            end
        end
        put("stroke{ " .. table.concat(parts, ", ") .. " }")
        put("")
    end
    return table.concat(lines, "\n")
end
-- }}}

return score
