-- tiny-notes.stand-in.lua
--
-- A stand-in script (see src/038-the-stand-in.lua) that plays every turn of
-- a case on the tiny-notes fixture source as a careful model would: the
-- outline and issue files come from tests/fixtures/tiny-notes-blueprint/,
-- the design's code and tests from tests/fixtures/tiny-notes-design/. Both
-- were written by hand from the source, the way a describe turn and then a
-- build turn would.
--
-- A case uses it with a one-line stand-in.lua:
--   return dofile("<project>/tests/fixtures/tiny-notes.stand-in.lua")({ root = "<project>/tests/fixtures", … })
--
-- Options (all optional) make chosen turns go wrong first, so the machine's
-- retries and holds can be shown:
--   bad_outline      number: the first N outline turns leave notes.lua uncovered
--   bad_describe     { [id] = N }: the first N describe turns of that issue
--                    leave out its Acceptance section
--   broken_build     { [id] = N }: the first N build or repair turns of that
--                    issue write a module that raises an error when loaded
--   also_writes      { [id] = { [design path] = text } }: that issue's first
--                    build also writes these files — a later build breaking
--                    an earlier issue's code, for the regression check
--   with_requests    true: play the requests in tests/fixtures/tiny-notes-requests/,
--                    one folder each: `request` (the person's words), `touched`
--                    (what a locate turn answers), `marker` (text the amended
--                    issue holds), `amend/<issue file>` (the amended issue),
--                    `design/<path>` (the code a rebuild writes once the blueprint
--                    holds the marker). Builds follow the blueprint: an issue whose
--                    file in the case holds a request's marker is built with that
--                    request's code.

-- {{{ local function read
local function read(path)
    local file = assert(io.open(path, "rb"), "fixture missing: " .. path)
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- Which design files each issue's build writes.
local BUILDS = {
    ["101"] = { "src/store.lua", "tests/101-note-storage.lua" },
    ["102"] = { "src/tags.lua", "tests/102-tag-parsing.lua" },
    ["103"] = { "src/dates.lua", "tests/103-dates.lua" },
    ["201"] = { "src/show.lua", "tests/201-showing-notes.lua" },
    ["202"] = { "src/search.lua", "tests/202-searching-notes.lua" },
    ["301"] = { "notes.lua", "tests/301-the-notes-command.lua" },
}

local ISSUE_FILES = {
    ["101"] = "101-note-storage.md", ["102"] = "102-tag-parsing.md", ["103"] = "103-dates.md",
    ["201"] = "201-showing-notes.md", ["202"] = "202-searching-notes.md", ["301"] = "301-the-notes-command.md",
}

-- {{{ local function list
local function list(folder)
    local pipe = io.popen("find '" .. folder .. "' -type f -printf '%P\\n' 2>/dev/null")
    local out = {}
    for name in pipe:read("*a"):gmatch("[^\n]+") do
        out[#out + 1] = name
    end
    pipe:close()
    table.sort(out)
    return out
end
-- }}}

-- {{{ local function load_requests
-- Every request folder, as { [name] = { touched, marker, amend = { [file] =
-- text }, design = { [path] = text } } }.
local function load_requests(folder)
    local requests = {}
    for _, file in ipairs(list(folder)) do
        local name, rest = file:match("^([^/]+)/(.+)$")
        if name then
            local r = requests[name] or { amend = {}, design = {} }
            requests[name] = r
            if rest == "touched" then
                r.touched = read(folder .. "/" .. file)
            elseif rest == "marker" then
                r.marker = read(folder .. "/" .. file)
            elseif rest:sub(1, 6) == "amend/" then
                r.amend[rest:sub(7)] = read(folder .. "/" .. file)
            elseif rest:sub(1, 7) == "design/" then
                r.design[rest:sub(8)] = read(folder .. "/" .. file)
            end
        end
    end
    return requests
end
-- }}}

return function(options)
    local root = options.root
    local blueprint = root .. "/tiny-notes-blueprint"
    local design = root .. "/tiny-notes-design"
    local script = {}
    if options.with_requests then
        options.requests = load_requests(root .. "/tiny-notes-requests")
    end

    script.outline = function(turn)
        local text = read(blueprint .. "/outline.tsv")
        if turn.attempt <= (options.bad_outline or 0) then
            -- Forget notes.lua: the coverage check must catch it.
            text = text:gsub("\tnotes%.lua\n", "\t-\n")
        end
        return { writes = { ["blueprint/outline.tsv"] = text } }
    end

    script.describe = function(turn)
        local name = ISSUE_FILES[turn.about]
        if not name then
            return { exit = 7, say = "no fixture issue for " .. turn.about }
        end
        local text = read(blueprint .. "/issues/" .. name)
        if turn.attempt <= ((options.bad_describe or {})[turn.about] or 0) then
            text = text:gsub("## Acceptance\n.-\n## Blocked by", "## Blocked by")
        end
        return { writes = { ["blueprint/issues/" .. name] = text } }
    end

    -- {{{ local function build_writes
    local function build_writes(turn, kind_attempt)
        local files = BUILDS[turn.about]
        if not files then
            return nil
        end
        -- The issue as the case's blueprint holds it now: after an amend it
        -- holds a request's marker, and the build follows it.
        local issue_now = ""
        local handle = io.open(turn.case_folder .. "/blueprint/issues/" .. ISSUE_FILES[turn.about], "rb")
        if handle then
            issue_now = handle:read("*a")
            handle:close()
        end
        local writes = {}
        for _, path in ipairs(files) do
            local text = read(design .. "/" .. path)
            for _, request in pairs(options.requests or {}) do
                if request.marker and request.design[path] and issue_now:find(request.marker, 1, true) then
                    text = request.design[path]
                end
            end
            local override = options.design_overrides and options.design_overrides[path]
            if override then
                text = override
            end
            if path:sub(1, 6) ~= "tests/" and kind_attempt <= ((options.broken_build or {})[turn.about] or 0) then
                text = "error('a broken build of issue " .. turn.about .. "')\n" .. text
            end
            writes["design/" .. path] = text
        end
        return writes
    end
    -- }}}

    -- A repair's attempt counts after the builds: the first repair of an
    -- issue built once is its second try overall.
    script.build = function(turn)
        local writes = build_writes(turn, turn.attempt)
        if not writes then
            return { exit = 7, say = "no fixture design for " .. turn.about }
        end
        if turn.attempt == 1 then
            for design_path, text in pairs((options.also_writes or {})[turn.about] or {}) do
                writes["design/" .. design_path] = text
            end
        end
        return { writes = writes }
    end
    script.repair = function(turn)
        local writes = build_writes(turn, turn.attempt + 1)
        if not writes then
            return { exit = 7, say = "no fixture design for " .. turn.about }
        end
        return { writes = writes }
    end

    script.locate = function(turn)
        local request = (options.requests or {})[turn.about]
        if not request then
            return { exit = 7, say = "no fixture for request " .. turn.about }
        end
        return { writes = { ["turn/touched"] = request.touched } }
    end

    script.amend = function(turn)
        local request = (options.requests or {})[turn.about]
        if not request then
            return { exit = 7, say = "no fixture for request " .. turn.about }
        end
        local writes = {}
        for name, text in pairs(request.amend or {}) do
            writes["blueprint/issues/" .. name] = text
        end
        if request.outline then
            writes["blueprint/outline.tsv"] = request.outline
        end
        return { writes = writes }
    end

    return script
end
