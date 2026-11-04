#!/usr/bin/env luajit
-- project-timeline-gather.lua - When did each project begin, and on which days
-- since then was it worked on?
--
-- In plain terms: the repository remembers two kinds of footprints. Every
-- commit says which files it changed and when; every saved conversation is
-- named for the days it ran. This reads both, sorts each footprint into the
-- project whose folder it landed in, and writes one JSON file listing, for
-- every project, its first day and the days it was worked on. It draws
-- nothing -- the PNG drawer and the HTML page read this file and draw.
--
-- Usage:
--   project-timeline-gather.lua                      -- JSON to standard output
--   project-timeline-gather.lua --out=FILE           -- JSON to FILE, summary to the terminal
--   project-timeline-gather.lua --dir=/path/to/delta-version   (any position)
--   project-timeline-gather.lua --sweep=N            -- commits touching more than N
--                                                       projects are sweeps (default 8)
--   project-timeline-gather.lua --today=YYYY-MM-DD   -- pin "today" (tests use it)
--   project-timeline-gather.lua --help
--
-- See project-timeline-gather.info.md for the JSON shape, and
-- delta-version/issues/067-project-lifetime-timeline.md for why.

-- {{{ DIR Configuration
-- DIR is delta-version; the monorepo it describes is DIR's parent, the same
-- arrangement census-projects.lua uses, so --dir can point at a fixture.
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local OUT_PATH = nil
local SWEEP_THRESHOLD = 8
local TODAY_OVERRIDE = nil
local WANTS_HELP = false
for _, argument in ipairs(arg) do
    local dir_value = argument:match("^%-%-dir=(.+)$")
    local out_value = argument:match("^%-%-out=(.+)$")
    local sweep_value = argument:match("^%-%-sweep=(%d+)$")
    local today_value = argument:match("^%-%-today=(%d%d%d%d%-%d%d%-%d%d)$")
    if dir_value then DIR = dir_value
    elseif out_value then OUT_PATH = out_value
    elseif sweep_value then SWEEP_THRESHOLD = tonumber(sweep_value)
    elseif today_value then TODAY_OVERRIDE = today_value
    elseif argument == "--help" or argument == "-h" then WANTS_HELP = true
    else
        -- an argument nobody asked for is an error, not something to ignore
        io.stderr:write("project-timeline-gather: unknown argument: " .. argument .. "\n")
        os.exit(2)
    end
end
local MONOREPO_ROOT = DIR:match("(.*)/.+$")
local CENSUS_PATH = DIR .. "/scripts/census-projects.lua"
-- }}}

-- {{{ local function print_help()
local function print_help()
    print([[
project-timeline-gather.lua - when each project began and which days it was worked on

  --out=FILE          write the JSON to FILE (and a summary to the terminal);
                      without it the JSON goes to standard output
  --dir=PATH          the delta-version folder (its parent is the repository read)
  --sweep=N           a commit touching more than N projects is a sweep, not
                      work on each of them (default 8)
  --today=YYYY-MM-DD  pin the day the bars end on (default: the real today)
  --help              this text]])
end
-- }}}

-- {{{ local function read_command(command)
-- Runs a read-only command and returns everything it printed. A failing
-- command stops the program: half a history drawn as if whole is worse than
-- no picture.
local function read_command(command)
    local handle = io.popen(command)
    local text = handle:read("*a")
    local ok, _, code = handle:close()
    if not ok then
        io.stderr:write("project-timeline-gather: command failed (" .. tostring(code) .. "): " .. command .. "\n")
        os.exit(1)
    end
    return text
end
-- }}}

-- {{{ local function shell_quote(text)
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function list_projects()
-- The census already decides what a project is (shelves, nesting, furniture),
-- so its list is taken as given rather than re-deciding it here. Names are
-- paths relative to the monorepo: "jurassic-maze", "games/physics-sim".
local function list_projects()
    local json = read_command("luajit " .. shell_quote(CENSUS_PATH) .. " --json --dir=" .. shell_quote(DIR))
    local names = {}
    for name in json:gmatch('{ "name": "([^"]+)"') do names[#names + 1] = name end
    if #names == 0 then
        io.stderr:write("project-timeline-gather: the census listed no projects\n")
        os.exit(1)
    end
    return names
end
-- }}}

-- {{{ local function make_attributor(project_names)
-- Returns a function from a repository-relative file path to the project it
-- belongs to, or false when it sits outside every project (root README,
-- shared scripts/). The longest matching project path wins, so a file under
-- games/physics-sim/ goes to games/physics-sim and never to a "games" shelf.
-- Lookup walks the path's own prefixes from longest to shortest, so the cost
-- per file is its depth, not the number of projects.
local function make_attributor(project_names)
    local is_project = {}
    for _, name in ipairs(project_names) do is_project[name] = true end
    return function(path)
        local prefix = path
        while true do
            prefix = prefix:match("^(.*)/[^/]*$")
            -- no slash left: the file is at the repository root
            if not prefix then return false end
            if is_project[prefix] then return prefix end
        end
    end
end
-- }}}

-- {{{ local month_numbers
-- Transcript file names spell months as three lower-case letters.
local month_numbers = {
    jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
    jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
}
-- }}}

-- {{{ local function day_string(time_value)
local function day_string(time_value)
    return os.date("%Y-%m-%d", time_value)
end
-- }}}

-- {{{ local function transcript_days(file_name)
-- The days a transcript's name says it covers, as YYYY-MM-DD strings, or nil
-- when the name carries no date. The shapes in use:
--   dec-15-25.md                       one day (month-day-two-digit-year)
--   dec-15-25_agent-1.md               one day; the suffix is which agent
--   aug-1-26-through-aug-4-26.md       every day from the first to the last
--   fill-phase-1-issue-files-sep-3-25  a date anywhere in the name counts
-- Noon is used when stepping through a range so a daylight-saving change can
-- never land a step on the same calendar day twice.
local function transcript_days(file_name)
    local found = {}
    for month_name, day, year in file_name:gmatch("(%a%a%a)%-(%d%d?)%-(%d%d)") do
        local month = month_numbers[month_name:lower()]
        -- a three-letter run that is not a month ("ase-1-25") is not a date
        if month then
            found[#found + 1] = os.time({ year = 2000 + tonumber(year), month = month,
                                         day = tonumber(day), hour = 12 })
        end
    end
    if #found == 0 then return nil end
    local first, last = found[1], found[#found]
    -- the "through" shape: two dates, a range between them
    if #found >= 2 and file_name:find("%-through%-") then
        if last < first then first, last = last, first end
        local days = {}
        local step = first
        while step <= last do
            days[#days + 1] = day_string(step)
            step = step + 86400
        end
        return days
    end
    -- one date, or several without "through": each named day on its own
    local days = {}
    for _, time_value in ipairs(found) do days[#days + 1] = day_string(time_value) end
    return days
end
-- }}}

-- {{{ local function read_commits(attribute, record_day)
-- One pass over the whole history. Each commit prints "@<author time>" and
-- then the files it changed, one per line. Files inside llm-transcripts/ are
-- left out here: transcripts are counted from their names below, and
-- re-exports rewrite every project's transcripts in one commit.
-- A commit whose files land in more than SWEEP_THRESHOLD projects is a sweep
-- (gitignore unification, a repository-wide rename). Its day is recorded under
-- "sweep" rather than "commit": it is not work on each project, but it does
-- prove each one existed that day. The repository's own first commit is one
-- (2025-12-15, every project at once), and for about thirty projects it is
-- their only footprint -- without sweep days they would have no birth at all.
-- Single process on purpose: git itself does the reading, and one pass over
-- the object store beats N passes split across threads.
local function read_commits(attribute, record_day)
    local log = read_command("git -C " .. shell_quote(MONOREPO_ROOT)
        .. " log --format=@%at --name-only --no-renames")
    local stats = { commits = 0, sweeps = 0, outside = 0 }
    local current_time, touched = nil, nil
    local function finish_commit()
        if not current_time then return end
        local count = 0
        for _ in pairs(touched) do count = count + 1 end
        local day = day_string(current_time)
        -- over the threshold: a sweep; at or under: ordinary work on each
        local source = "commit"
        if count > SWEEP_THRESHOLD then
            stats.sweeps = stats.sweeps + 1
            source = "sweep"
        end
        for project in pairs(touched) do record_day(project, source, day) end
    end
    for line in log:gmatch("[^\n]+") do
        local time_text = line:match("^@(%d+)$")
        if time_text then
            finish_commit()
            stats.commits = stats.commits + 1
            current_time, touched = tonumber(time_text), {}
        elseif not line:find("/llm%-transcripts/") then
            local project = attribute(line)
            if project then touched[project] = true else stats.outside = stats.outside + 1 end
        end
    end
    finish_commit()
    return stats
end
-- }}}

-- {{{ local function read_transcripts(attribute, record_day)
-- Every file sitting directly in some project's llm-transcripts/ folder. Files
-- in deeper folders (an HTML/ export) are copies of these and are not read.
local function read_transcripts(attribute, record_day)
    local listing = read_command("find " .. shell_quote(MONOREPO_ROOT)
        .. " -maxdepth 4 -type f -path '*/llm-transcripts/*'")
    local stats = { files = 0, unparsed = {} }
    local root_length = #MONOREPO_ROOT + 2
    for full_path in listing:gmatch("[^\n]+") do
        local relative = full_path:sub(root_length)
        local folder, file_name = relative:match("^(.*)/llm%-transcripts/([^/]+)$")
        -- a file nested below llm-transcripts/ (folder is nil) is a copy
        if folder then
            local project = attribute(folder .. "/x")
            if project == folder then
                local days = transcript_days(file_name)
                if days then
                    stats.files = stats.files + 1
                    for _, day in ipairs(days) do record_day(project, "transcript", day) end
                else
                    stats.unparsed[#stats.unparsed + 1] = relative
                end
            end
        end
    end
    table.sort(stats.unparsed)
    return stats
end
-- }}}

-- {{{ local function json_string(text)
local function json_string(text)
    return '"' .. text:gsub('[%c"\\]', function(character)
        if character == '"' then return '\\"' end
        if character == "\\" then return "\\\\" end
        return string.format("\\u%04x", character:byte())
    end) .. '"'
end
-- }}}

-- {{{ local function json_day_list(set)
local function json_day_list(set)
    local days = {}
    for day in pairs(set) do days[#days + 1] = day end
    table.sort(days)
    local quoted = {}
    for index, day in ipairs(days) do quoted[index] = '"' .. day .. '"' end
    return "[" .. table.concat(quoted, ",") .. "]", days
end
-- }}}

-- {{{ local SOURCES
-- The three kinds of footprint, in the order they are written to the JSON.
-- Each project keeps a set of days and a tally per source; adding a fourth
-- source is one more name here and one more call to record_day.
local SOURCES = { "commit", "transcript", "sweep" }
-- }}}

-- {{{ local function main()
local function main()
    if WANTS_HELP then print_help() return end
    local project_names = list_projects()
    local attribute = make_attributor(project_names)

    -- per project, per source: a set of days (YYYY-MM-DD strings as keys,
    -- true as values) and a tally (integer) of footprints of that source
    local records = {}
    for _, name in ipairs(project_names) do
        local record = { days = {}, counts = {} }
        for _, source in ipairs(SOURCES) do record.days[source], record.counts[source] = {}, 0 end
        records[name] = record
    end
    local function record_day(project, source, day)
        local record = records[project]
        record.days[source][day] = true
        record.counts[source] = record.counts[source] + 1
    end

    local commit_stats = read_commits(attribute, record_day)
    local transcript_stats = read_transcripts(attribute, record_day)
    local today = TODAY_OVERRIDE or day_string(os.time())

    -- first day = the earliest day from any source; none at all = undated
    local dated, undated = {}, {}
    for _, name in ipairs(project_names) do
        local record = records[name]
        local entry = { name = name, record = record, json = {} }
        for _, source in ipairs(SOURCES) do
            local json, list = json_day_list(record.days[source])
            entry.json[source] = json
            if list[1] and (not entry.first or list[1] < entry.first) then entry.first = list[1] end
        end
        if entry.first then dated[#dated + 1] = entry else undated[#undated + 1] = name end
    end
    -- birth order, ties broken by name so the picture never reshuffles itself
    table.sort(dated, function(a, b)
        if a.first ~= b.first then return a.first < b.first end
        return a.name < b.name
    end)
    table.sort(undated)

    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "made_by": ' .. json_string("delta-version/scripts/project-timeline-gather.lua"
        .. " (issue 067): one pass of git log plus the dates in llm-transcripts file names,"
        .. " sorted into the census's projects, so the PNG drawer and HTML page have one source") .. ","
    lines[#lines + 1] = '  "generated": "' .. os.date("%Y-%m-%dT%H:%M:%S") .. '",'
    lines[#lines + 1] = '  "today": "' .. today .. '",'
    lines[#lines + 1] = '  "sweep_threshold": ' .. SWEEP_THRESHOLD .. ","
    lines[#lines + 1] = '  "commits_read": ' .. commit_stats.commits .. ","
    lines[#lines + 1] = '  "sweeps": ' .. commit_stats.sweeps .. ","
    lines[#lines + 1] = '  "transcripts_read": ' .. transcript_stats.files .. ","
    lines[#lines + 1] = '  "projects": ['
    for index, entry in ipairs(dated) do
        -- per source: "<source>s" (tally) and "<source>_days" (sorted list)
        local fields = { '"name": ' .. json_string(entry.name), '"first_day": "' .. entry.first .. '"' }
        for _, source in ipairs(SOURCES) do
            fields[#fields + 1] = '"' .. source .. 's": ' .. entry.record.counts[source]
        end
        for _, source in ipairs(SOURCES) do
            fields[#fields + 1] = '"' .. source .. '_days": ' .. entry.json[source]
        end
        lines[#lines + 1] = "    { " .. table.concat(fields, ", ") .. " }" .. (index < #dated and "," or "")
    end
    lines[#lines + 1] = "  ],"
    local quoted_undated, quoted_unparsed = {}, {}
    for index, name in ipairs(undated) do quoted_undated[index] = json_string(name) end
    for index, name in ipairs(transcript_stats.unparsed) do quoted_unparsed[index] = json_string(name) end
    lines[#lines + 1] = '  "undated": [' .. table.concat(quoted_undated, ", ") .. "],"
    lines[#lines + 1] = '  "unparsed_transcripts": [' .. table.concat(quoted_unparsed, ", ") .. "]"
    lines[#lines + 1] = "}"
    local json = table.concat(lines, "\n") .. "\n"

    -- without --out the JSON is the whole output, so it can be piped
    if not OUT_PATH then io.write(json) return end
    local file = assert(io.open(OUT_PATH, "w"))
    file:write(json)
    file:close()
    print(string.format("project-timeline: %d projects dated, %d undated", #dated, #undated))
    print(string.format("  commits read: %d (sweeps touching more than %d projects, kept apart: %d)",
        commit_stats.commits, SWEEP_THRESHOLD, commit_stats.sweeps))
    print(string.format("  transcripts read: %d (names without a date: %d)",
        transcript_stats.files, #transcript_stats.unparsed))
    if #dated > 0 then
        print(string.format("  first project: %s on %s; today: %s", dated[1].name, dated[1].first, today))
    end
    for _, name in ipairs(undated) do print("  undated (never committed, never talked about): " .. name) end
    print("  wrote " .. OUT_PATH)
end
-- }}}

main()
