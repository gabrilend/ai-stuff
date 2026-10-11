#!/usr/bin/env luajit
-- reading-walk-map.lua - Turns a project into a map of stops for a reader to
-- walk, one function or datastructure at a time.
--
-- In plain terms: every function and datastructure in a house project opens
-- with a fold marker, and every source file is numbered in the order it should
-- be read. This reads the files in that order, makes one stop per fold marker,
-- and gives each stop what a reader needs: what it is (from the file's
-- .info.md page, or from the comment under the marker when the page has no
-- entry), where else it is used, the other ways it could have been done and why
-- they were not (only where someone wrote that down), and the commit that first
-- brought its file into the project. The result is one data file. It knows
-- nothing about who will read it; reading-walk.lua is the walk.
--
-- The work is shared out: one pass reads each source file's stops, a second
-- pass reads every source and issue file for uses and recorded reasons. Each
-- pass runs as one worker process per CPU, each with its own share of files.
--
-- Usage:
--   reading-walk-map.lua <project-dir>            -- build the map, print a report
--   reading-walk-map.lua <project-dir> --src=lib  -- read another source folder
--   reading-walk-map.lua <project-dir> --out=FILE -- write the map somewhere else
--   reading-walk-map.lua ... --workers=N          -- how many workers (default: CPU count)
--   reading-walk-map.lua ... --dir=PATH           -- delta-version's home (scratch space)
--   reading-walk-map.lua --stops-worker LIST OUT PROJECT SRC   -- internal: first pass
--   reading-walk-map.lua --reasons-worker LIST OUT PROJECT NAMES -- internal: second pass
--
-- See reading-walk-map.info.md for the map's fields, and
-- delta-version/issues/065-the-reading-walk.md for why it exists.

-- {{{ DIR Configuration
-- DIR is delta-version's home: its tmp/ link holds this tool's scratch space and
-- the default place the map is written. The project being mapped is a separate,
-- positional argument, so a map of any project lands in the same RAM tier.
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local TARGET = nil
local SOURCE_FOLDER = "src"
local OUT_PATH = nil
local WORKER_COUNT = nil
local worker_mode = nil
local worker_arguments = {}
do
    local index = 1
    while arg[index] do
        local argument = arg[index]
        local dir_value = argument:match("^%-%-dir=(.+)$")
        local src_value = argument:match("^%-%-src=(.+)$")
        local out_value = argument:match("^%-%-out=(.+)$")
        local workers_value = argument:match("^%-%-workers=(%d+)$")
        -- each option sets one setting; a worker mode swallows the rest of the
        -- arguments as its own; anything else is the project to map
        if dir_value then DIR = dir_value
        elseif src_value then SOURCE_FOLDER = src_value
        elseif out_value then OUT_PATH = out_value
        elseif workers_value then WORKER_COUNT = tonumber(workers_value)
        elseif argument == "--stops-worker" or argument == "--reasons-worker" then
            worker_mode = argument
            for rest = index + 1, #arg do worker_arguments[#worker_arguments + 1] = arg[rest] end
            break
        else TARGET = argument
        end
        index = index + 1
    end
end
local SCRIPT_PATH = arg[0]
local MONOREPO_SCRIPTS = "/mnt/mtwo/programming/ai-stuff/scripts"
-- }}}

-- {{{ Configuration
local config = {
    -- The comment opener for each kind of source file. A file whose extension
    -- is not here has no fold markers this tool can read, so it is not a source
    -- file for the walk. Read as a table rather than a chain of checks so a new
    -- language is one line.
    comment_by_extension = {
        lua = "--", c = "//", h = "//", js = "//", sh = "#", bash = "#",
    },

    -- Phrases that mark a passage as naming another way and why it was not
    -- taken. Matched lower-cased. A passage with none of these is not a
    -- recorded reason, however close to one it reads: the walk shows what was
    -- written down and nothing else.
    reason_markers = {
        "decided against", "why not", "instead of", "rather than",
        "not chosen", "was considered", "set aside", "would have",
        "would be", "the choice", "chosen", "because",
    },

    -- A short, common name ("main", "run") would match half the issue files.
    -- Issue lines are only searched for names at least this long, or holding
    -- an underscore or a dot.
    shortest_issue_name = 5,

    -- Every worker output ends with this field set; a worker that died
    -- part-way leaves a file without it, which is the only honest signal
    -- (the shell's wait reports success either way).
    finished_field = "finished",
}
-- }}}

-- {{{ local function fail()
-- Stops the run with a message. Errors here are reported, never worked around.
local function fail(message)
    io.stderr:write("reading-walk-map: ", message, "\n")
    os.exit(1)
end
-- }}}

-- {{{ local function read_lines()
-- A file as a list of its lines. A file that cannot be opened is an error: the
-- file list came from the disk a moment ago, so a missing file means something
-- else is changing the tree underneath the run.
local function read_lines(path)
    local handle = io.open(path, "r")
    if not handle then fail("cannot read " .. path) end
    local lines = {}
    for line in handle:lines() do lines[#lines + 1] = line end
    handle:close()
    return lines
end
-- }}}

-- {{{ local function read_command()
-- A shell command's output, as lines.
local function read_command(command)
    local pipe = io.popen(command)
    local lines = {}
    for line in pipe:lines() do lines[#lines + 1] = line end
    pipe:close()
    return lines
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function serialize()
-- Writes a value as Lua source, so the map and the workers' outputs are read
-- back with loadfile and need no parser of their own. Keys are sorted so the
-- same project always gives the same file (a map can be compared with the
-- last one by diff).
local function serialize(value, indent)
    indent = indent or ""
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind ~= "table" then fail("cannot write a " .. kind .. " into the map") end
    local inner = indent .. "  "
    local parts = {}
    -- a list is written in order; a record is written key by sorted key
    if #value > 0 then
        for _, item in ipairs(value) do parts[#parts + 1] = inner .. serialize(item, inner) end
    else
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = inner .. "[" .. string.format("%q", key) .. "] = " .. serialize(value[key], inner)
        end
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end
-- }}}

-- {{{ local function write_data()
local function write_data(path, header, value)
    local handle = io.open(path, "w")
    if not handle then fail("cannot write " .. path) end
    handle:write(header, "\nreturn ", serialize(value), "\n")
    handle:close()
end
-- }}}

-- {{{ local function load_data()
-- Reads a file written by write_data, in an empty environment: it is data, and
-- has no business calling anything.
local function load_data(path)
    local chunk, problem = loadfile(path)
    if not chunk then fail("cannot read data " .. path .. ": " .. tostring(problem)) end
    setfenv(chunk, {})
    return chunk()
end
-- }}}

-- {{{ local function extension_of()
local function extension_of(path)
    return path:match("%.([%w]+)$") or ""
end
-- }}}

-- {{{ local function is_comment()
-- Whether a line is only a comment, and its text without the opener.
local function is_comment(line, opener)
    local text = line:match("^%s*" .. opener:gsub("%p", "%%%0") .. "%s?(.*)$")
    return text ~= nil, text
end
-- }}}

-- {{{ local function has_reason_marker()
local function has_reason_marker(text)
    local lowered = text:lower()
    for _, marker in ipairs(config.reason_markers) do
        if lowered:find(marker, 1, true) then return true end
    end
    return false
end
-- }}}

-- {{{ local function first_sentence()
-- The summary a reader can skip down to: the description's first sentence.
local function first_sentence(text)
    local flat = text:gsub("%s+", " "):gsub("^ ", "")
    local sentence = flat:match("^(.-[%.!?])%s") or flat
    if #sentence > 240 then sentence = sentence:sub(1, 237) .. "..." end
    return sentence
end
-- }}}

-- {{{ local function name_from_title()
-- A fold marker's title, taken apart: "local function split(x, y) -- note"
-- gives name "split", short name "split", kind "function", gloss "note".
-- "M.flatten(path, tolerance)" gives name "M.flatten", short "flatten".
-- "MAX_DEPTH -- how many times" gives a datastructure named MAX_DEPTH.
local function name_from_title(title)
    local main, gloss = title:match("^(.-)%s+%-%-%s+(.*)$")
    if not main then main, gloss = title, "" end
    local is_function = main:find("function", 1, true) ~= nil or main:find("(", 1, true) ~= nil
    main = main:gsub("^local%s+function%s+", ""):gsub("^function%s+", ""):gsub("^local%s+", "")
    -- A fold can also open a passage of prose ("ONE OF THESE PER PROCESS, NOT
    -- ONE PER FILE THAT ASKS"): a heading, not a name. It is a stop in the
    -- story, but nothing calls it, so it gets no short name and no uses.
    local is_name = main:match("^[%a_][%w_%.:]*%s*%(") or main:match("^[%a_][%w_%.:]*%s*$")
    if not is_name then
        return { name = title, short = "", gloss = "", kind = "passage", exported = false }
    end
    local name = main:match("^([%a_][%w_%.:]*)")
    local short = name:match("([%a_][%w_]*)$") or name
    return {
        name = name, short = short, gloss = gloss,
        kind = is_function and "function" or "datastructure",
        exported = name:find("[%.:]") ~= nil,
    }
end
-- }}}

-- {{{ local function read_info_page()
-- A source file's .info.md page, as short name -> description. Two shapes are
-- read: a "### `name(args)`" section (its paragraphs, until the next heading)
-- and a table row "| `name(args)` | text |". A section beats a row, being the
-- longer account. The page sits beside the file as either name.info.md (house
-- style) or name.ext.info.md (some projects); both are tried.
local function read_info_page(source_path)
    local candidates = { source_path:gsub("%.[%w]+$", "") .. ".info.md", source_path .. ".info.md" }
    local descriptions, from_rows = {}, {}
    for _, page in ipairs(candidates) do
        local handle = io.open(page, "r")
        if handle then
            local current, buffer = nil, {}
            local function close_section()
                if current and #buffer > 0 then descriptions[current] = table.concat(buffer, " ") end
                current, buffer = nil, {}
            end
            for line in handle:lines() do
                local section = line:match("^###%s+`([^`]+)`")
                local row_name, row_text = line:match("^|%s*`([^`]+)`%s*|%s*(.-)%s*|%s*$")
                -- a heading starts a section (or ends one); a row is recorded;
                -- other lines belong to the open section, if any
                if section then
                    close_section()
                    local key = section:match("([%a_][%w_]*)%s*%(") or section:match("([%a_][%w_]*)$") or section
                    current = key
                elseif line:match("^#") then
                    close_section()
                elseif row_name then
                    local key = row_name:match("([%a_][%w_]*)%s*%(") or row_name:match("([%a_][%w_]*)$") or row_name
                    from_rows[key] = row_text
                elseif current and line:match("%S") then
                    buffer[#buffer + 1] = line:gsub("^%s+", "")
                end
            end
            close_section()
            handle:close()
        end
    end
    for key, text in pairs(from_rows) do
        if not descriptions[key] then descriptions[key] = text end
    end
    return descriptions
end
-- }}}

-- {{{ local function first_commit()
-- The commit that first brought a file into the project: its date and subject.
-- A file never committed is not yet part of the story, and says so.
local function first_commit(project, relative_path)
    local lines = read_command(string.format(
        "git -C %s log --diff-filter=A --format='%%as%%x09%%s' -- %s",
        shell_quote(project), shell_quote(relative_path)))
    local last = lines[#lines]
    if not last then return { date = "", subject = "not yet in history" } end
    local date, subject = last:match("^(%S+)\t(.*)$")
    return { date = date, subject = subject }
end
-- }}}

-- {{{ local function stops_of_file()
-- One source file's stops: one per fold marker, with its span, description,
-- the comment passages inside it that record a reason, and its file's chapter.
local function stops_of_file(project, source_folder, relative_path)
    local path = project .. "/" .. relative_path
    local opener = config.comment_by_extension[extension_of(path)]
    local lines = read_lines(path)
    local info = read_info_page(path)
    local chapter = first_commit(project, relative_path)
    local quoted = opener:gsub("%p", "%%%0")
    local stops, open = {}, {}
    for number, line in ipairs(lines) do
        local title = line:match("^%s*" .. quoted .. "%s*{{{%s*(.-)%s*$")
        local closes = line:match("^%s*" .. quoted .. "%s*}}}") ~= nil
        -- an opener starts a stop (folds can nest, so open ones are a stack);
        -- a closer ends the innermost open stop
        if title then
            local stop = name_from_title(title)
            stop.title, stop.file, stop.line = title, relative_path, number
            stop.chapter = chapter
            open[#open + 1] = stop
            stops[#stops + 1] = stop
        elseif closes then
            local stop = table.remove(open)
            if stop then stop.end_line = number end
        end
    end
    for _, stop in ipairs(open) do stop.end_line = #lines end

    for _, stop in ipairs(stops) do
        -- the comment directly under the marker, before any code
        local leading = {}
        local definition_line = stop.line
        for number = stop.line + 1, stop.end_line do
            local comment, text = is_comment(lines[number], opener)
            if comment then leading[#leading + 1] = text
            else definition_line = number; break end
        end
        stop.definition_line = definition_line

        -- the description: the .info.md page first; the source comment when the
        -- page has no entry, marked as such so the reader (and the report)
        -- knows the page is missing one
        if info[stop.short] then
            stop.description, stop.description_source = info[stop.short], "info.md"
        else
            local text = table.concat(leading, " "):gsub("%s+", " "):gsub("^ ", "")
            if stop.gloss ~= "" then text = stop.gloss .. ". " .. text end
            if text:match("%S") then
                stop.description, stop.description_source = text, "source comment"
            else
                stop.description, stop.description_source = "", "none"
            end
        end
        stop.summary = first_sentence(stop.description ~= "" and stop.description or stop.title)

        -- recorded reasons inside the stop's own comments: each comment
        -- paragraph (a run of comment lines) holding a marker phrase
        stop.alternatives = {}
        local paragraph, paragraph_start = {}, nil
        local function close_paragraph()
            local text = table.concat(paragraph, " "):gsub("%s+", " ")
            if #paragraph > 0 and has_reason_marker(text) then
                stop.alternatives[#stop.alternatives + 1] = {
                    source = relative_path, line = paragraph_start, text = text,
                }
            end
            paragraph, paragraph_start = {}, nil
        end
        for number = stop.line + 1, stop.end_line do
            local comment, text = is_comment(lines[number], opener)
            if comment and text:match("%S") and not text:match("^{{{") and not text:match("^}}}") then
                paragraph_start = paragraph_start or number
                paragraph[#paragraph + 1] = text
            else
                close_paragraph()
            end
        end
        close_paragraph()
        stop.gloss = nil
    end
    return stops
end
-- }}}

-- {{{ local function run_stops_worker()
-- First pass, one worker: its share of source files, read for their stops.
local function run_stops_worker(list_path, out_path, project, source_folder)
    local result = { files = {} }
    for _, relative_path in ipairs(read_lines(list_path)) do
        result.files[#result.files + 1] = { file = relative_path, stops = stops_of_file(project, source_folder, relative_path) }
    end
    result[config.finished_field] = true
    write_data(out_path, "-- reading-walk-map first-pass share", result)
end
-- }}}

-- {{{ local function run_reasons_worker()
-- Second pass, one worker: its share of source and issue files, read for uses
-- of every stop and for issue lines that record a reason about one.
--
-- Each line is broken into words and each word looked up in the table of stop
-- names, so the cost is one table lookup per word whatever the number of stops
-- (checking every stop's name against every line would be stops x lines).
--
-- A local function's uses are counted only in its own file: two files may each
-- have a local "split", and they are not the same thing. An exported one
-- (M.flatten) counts in any file, but outside its own file only when written
-- after a dot or colon, the way another file has to call it.
local function run_reasons_worker(list_path, out_path, project, names_path)
    local names = load_data(names_path)
    local by_short = {}
    for index, entry in ipairs(names) do
        local list = by_short[entry.short] or {}
        list[#list + 1] = { index = index, entry = entry }
        by_short[entry.short] = list
    end
    local result = { uses = {}, reasons = {} }
    for _, line_of_list in ipairs(read_lines(list_path)) do
        local kind, relative_path = line_of_list:match("^(%w+)\t(.*)$")
        local lines = read_lines(project .. "/" .. relative_path)
        local opener = config.comment_by_extension[extension_of(relative_path)]
        for number, line in ipairs(lines) do
            -- a source line is searched for uses (not its comments); an issue
            -- line is searched for a recorded reason naming a stop
            if kind == "source" then
                if not is_comment(line, opener) then
                    local seen = {}
                    for word in line:gmatch("[%a_][%w_]*") do
                        for _, candidate in ipairs(by_short[word] or {}) do
                            local entry = candidate.entry
                            local same_file = entry.file == relative_path
                            local is_definition = same_file and (number == entry.line or number == entry.definition_line)
                            local counts
                            if is_definition then counts = false
                            elseif same_file then counts = true
                            elseif entry.exported then counts = line:find("[%.:]" .. word .. "%f[^%w_]") ~= nil
                            else counts = false end
                            if counts and not seen[candidate.index] then
                                seen[candidate.index] = true
                                result.uses[#result.uses + 1] = {
                                    stop = candidate.index, file = relative_path, line = number,
                                    text = line:gsub("^%s+", ""):sub(1, 160),
                                }
                            end
                        end
                    end
                end
            end
        end
        if kind == "issue" then
            -- An issue file is read by paragraph (lines between blank lines),
            -- not by line: prose is wrapped, and a reason cut at the line
            -- break reads as half a thought. A paragraph counts when it holds
            -- a marker phrase and names the stop.
            --
            -- A name counts as naming the stop when it is long (five letters
            -- or more), written the way code writes it (with an underscore or
            -- a dot), or four letters and the only stop of that name. Shorter
            -- or shared names ("run", "main") would tie the stop to every
            -- paragraph that uses the ordinary word.
            local start = 1
            for number = 1, #lines + 1 do
                local line = lines[number]
                if line == nil or not line:match("%S") then
                    local paragraph = table.concat(lines, " ", start, number - 1)
                    if number > start and has_reason_marker(paragraph) then
                        local seen = {}
                        for word in paragraph:gmatch("[%a_][%w_%.]*") do
                            local short = word:match("([%a_][%w_]*)$")
                            local candidates = by_short[short] or {}
                            for _, candidate in ipairs(candidates) do
                                local specific = #short >= config.shortest_issue_name
                                    or word:find("[_%.]") ~= nil
                                    or (#short >= 4 and #candidates == 1)
                                if specific and not seen[candidate.index] then
                                    seen[candidate.index] = true
                                    result.reasons[#result.reasons + 1] = {
                                        stop = candidate.index, source = relative_path, line = start,
                                        text = paragraph:gsub("%s+", " "):gsub("^ ", ""):sub(1, 700),
                                    }
                                end
                            end
                        end
                    end
                    start = number + 1
                end
            end
        end
    end
    result[config.finished_field] = true
    write_data(out_path, "-- reading-walk-map second-pass share", result)
end
-- }}}

-- {{{ local function ensure_scratch()
-- A fresh folder in the RAM tier for this run's shares, rebuilt first if a
-- reboot emptied the tier.
local function ensure_scratch()
    local tiers = dofile(MONOREPO_SCRIPTS .. "/libs/ensure-ram-tiers.lua")
    tiers.ensure(DIR)
    local scratch = DIR .. "/tmp/shared-memory/reading-walk/run-" .. os.time()
    os.execute("mkdir -p " .. shell_quote(scratch))
    return scratch
end
-- }}}

-- {{{ local function run_in_parallel()
-- Deals work lines round-robin into one share per worker, starts every worker
-- at once, waits for all, and returns their outputs in share order. A worker
-- whose output lacks the finished field died part-way, and the run stops.
local function run_in_parallel(scratch, label, work, mode, extra_arguments)
    local count = WORKER_COUNT or tonumber(read_command("nproc")[1])
    if count > #work then count = #work end
    if count < 1 then return {} end
    local shares = {}
    for index = 1, count do shares[index] = {} end
    for index, item in ipairs(work) do
        local share = shares[(index - 1) % count + 1]
        share[#share + 1] = item
    end
    local commands, outputs = {}, {}
    for index, share in ipairs(shares) do
        local list_path = string.format("%s/%s-%d.list", scratch, label, index)
        local out_path = string.format("%s/%s-%d.lua", scratch, label, index)
        local handle = io.open(list_path, "w")
        handle:write(table.concat(share, "\n"), "\n")
        handle:close()
        outputs[index] = out_path
        local quoted = {}
        for _, argument in ipairs(extra_arguments) do quoted[#quoted + 1] = shell_quote(argument) end
        commands[#commands + 1] = string.format("luajit %s %s %s %s %s &",
            shell_quote(SCRIPT_PATH), mode, shell_quote(list_path), shell_quote(out_path), table.concat(quoted, " "))
    end
    os.execute("bash -c " .. shell_quote(table.concat(commands, "\n") .. "\nwait"))
    local results = {}
    for index, out_path in ipairs(outputs) do
        local handle = io.open(out_path, "r")
        if not handle then fail("a worker wrote nothing: " .. out_path) end
        handle:close()
        local data = load_data(out_path)
        if not data[config.finished_field] then fail("a worker stopped part-way: " .. out_path) end
        results[index] = data
    end
    return results
end
-- }}}

-- {{{ local function list_files()
-- Files under a folder of the project, relative to the project, sorted. Sorted
-- by name is reading order: index numbers are zero-padded ("009", "017a"), so
-- they sort as they read, and unnumbered files (external libraries are given
-- high numbers or none) fall after.
local function list_files(project, folder)
    local files = read_command(string.format(
        "cd %s && if [ -d %s ]; then find %s -type f | sort; fi", shell_quote(project), shell_quote(folder), shell_quote(folder)))
    return files
end
-- }}}

-- {{{ local function build_map()
local function build_map()
    if not TARGET then fail("usage: reading-walk-map.lua <project-dir> [--src=FOLDER] [--out=FILE] [--workers=N]") end
    local project = TARGET:gsub("/+$", "")
    local probe = io.open(project .. "/" .. SOURCE_FOLDER, "r")
    if not probe then fail("no " .. SOURCE_FOLDER .. "/ folder in " .. project) end
    probe:close()

    local sources = {}
    for _, relative_path in ipairs(list_files(project, SOURCE_FOLDER)) do
        if config.comment_by_extension[extension_of(relative_path)] then sources[#sources + 1] = relative_path end
    end
    if #sources == 0 then fail("no source files with fold markers in " .. project .. "/" .. SOURCE_FOLDER) end

    local scratch = ensure_scratch()

    -- first pass: stops, file by file, put back in reading order
    local first = run_in_parallel(scratch, "stops", sources, "--stops-worker", { project, SOURCE_FOLDER })
    local by_file = {}
    for _, share in ipairs(first) do
        for _, entry in ipairs(share.files) do by_file[entry.file] = entry.stops end
    end
    local stops = {}
    for _, relative_path in ipairs(sources) do
        for _, stop in ipairs(by_file[relative_path]) do
            stop.index = #stops + 1
            stops[#stops + 1] = stop
        end
    end

    -- second pass: uses and issue-file reasons, over sources and issues
    local names = {}
    for index, stop in ipairs(stops) do
        names[index] = { name = stop.name, short = stop.short, file = stop.file, line = stop.line,
            definition_line = stop.definition_line, exported = stop.exported }
    end
    local names_path = scratch .. "/names.lua"
    write_data(names_path, "-- reading-walk-map stop names", names)
    local work = {}
    for _, relative_path in ipairs(sources) do work[#work + 1] = "source\t" .. relative_path end
    for _, relative_path in ipairs(list_files(project, "issues")) do
        if relative_path:match("%.md$") then work[#work + 1] = "issue\t" .. relative_path end
    end
    local second = run_in_parallel(scratch, "reasons", work, "--reasons-worker", { project, names_path })
    for _, stop in ipairs(stops) do stop.uses = {} end
    for _, share in ipairs(second) do
        for _, use in ipairs(share.uses) do
            local list = stops[use.stop].uses
            list[#list + 1] = { file = use.file, line = use.line, text = use.text }
        end
        for _, reason in ipairs(share.reasons) do
            local list = stops[reason.stop].alternatives
            list[#list + 1] = { source = reason.source, line = reason.line, text = reason.text }
        end
    end
    for _, stop in ipairs(stops) do
        table.sort(stop.uses, function(a, b) return a.file < b.file or (a.file == b.file and a.line < b.line) end)
    end

    -- the map, and a report of what was found and what was missing
    local project_name = project:match("([^/]+)$")
    local out_path = OUT_PATH or (DIR .. "/tmp/shared-memory/reading-walk/" .. project_name .. ".map.lua")
    local map = { project = project, project_name = project_name, source_folder = SOURCE_FOLDER,
        built = os.date("%Y-%m-%d %H:%M:%S"), stops = stops }
    write_data(out_path,
        "-- Made by delta-version/scripts/reading-walk-map.lua, by reading " .. project ..
        " for its fold markers, .info.md pages, issue files and git history, so a reader can walk it one stop at a time (issue 065).",
        map)

    local from_page, from_comment, with_none, with_reason, unused = 0, 0, 0, 0, 0
    for _, stop in ipairs(stops) do
        -- each stop counts toward exactly one description source
        if stop.description_source == "info.md" then from_page = from_page + 1
        elseif stop.description_source == "source comment" then from_comment = from_comment + 1
        else with_none = with_none + 1 end
        if #stop.alternatives > 0 then with_reason = with_reason + 1 end
        if #stop.uses == 0 then unused = unused + 1 end
    end
    io.write(string.format("map of %s: %d stops in %d files\n", project_name, #stops, #sources))
    io.write(string.format("  described by .info.md page:         %d\n", from_page))
    io.write(string.format("  described only by source comment:   %d   (the page has no entry for these)\n", from_comment))
    io.write(string.format("  not described at all:               %d\n", with_none))
    io.write(string.format("  with a recorded reason:             %d\n", with_reason))
    io.write(string.format("  never used:                         %d\n", unused))
    io.write("  written to ", out_path, "\n")
end
-- }}}

-- {{{ local function main()
-- Which job this process is: one of the two worker passes, or the builder that
-- starts them.
local jobs = {
    ["--stops-worker"] = function() run_stops_worker(worker_arguments[1], worker_arguments[2], worker_arguments[3], worker_arguments[4]) end,
    ["--reasons-worker"] = function() run_reasons_worker(worker_arguments[1], worker_arguments[2], worker_arguments[3], worker_arguments[4]) end,
}
local function main()
    local job = jobs[worker_mode or ""] or build_map
    job()
end
-- }}}

main()
