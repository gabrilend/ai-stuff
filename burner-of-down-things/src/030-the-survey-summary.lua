-- 030-the-survey-summary.lua
--
-- The viewing side of the survey, kept apart from everything that generates
-- it: reads survey/files.tsv and survey/links.tsv and nothing else, and
-- writes survey/summary.txt — counts by language and role, the largest code
-- files, the files most included by others (likely foundations), the files
-- that include others but are included by none (likely entry points), and
-- every outside dependency by name. It can be rebuilt at any time without
-- the source being present.

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")

local summary = {}

-- {{{ local function top
-- The first `n` entries of an array sorted by `better`.
local function top(items, n, better)
    table.sort(items, better)
    local out = {}
    for i = 1, math.min(n, #items) do
        out[i] = items[i]
    end
    return out
end
-- }}}

-- {{{ function summary.compute
-- Reads the two tables and returns a summary table:
--   totals        { files, lines, bytes, links_inside, links_outside }
--   by_language   array of { name, files, lines } (most lines first)
--   by_role       array of { name, files, lines }
--   largest       array of { path, lines } (code files)
--   foundations   array of { path, included_by }
--   entry_points  array of paths (C .c files excluded)
--   compile_units number of C .c files that include others
--   outside       array of { name, used_by }
function summary.compute(survey_folder)
    local files = text_tables.read(survey_folder .. "/files.tsv")
    local links = text_tables.read(survey_folder .. "/links.tsv")
    local totals = { files = #files, lines = 0, bytes = 0, links_inside = 0, links_outside = 0 }
    local languages, roles = {}, {}
    local code = {}
    for _, f in ipairs(files) do
        local lines, bytes = tonumber(f.lines), tonumber(f.bytes)
        totals.lines = totals.lines + lines
        totals.bytes = totals.bytes + bytes
        languages[f.language] = languages[f.language] or { name = f.language, files = 0, lines = 0 }
        languages[f.language].files = languages[f.language].files + 1
        languages[f.language].lines = languages[f.language].lines + lines
        roles[f.role] = roles[f.role] or { name = f.role, files = 0, lines = 0 }
        roles[f.role].files = roles[f.role].files + 1
        roles[f.role].lines = roles[f.role].lines + lines
        if f.role == "code" then
            code[#code + 1] = { path = f.path, lines = lines }
        end
    end
    local included_by, includes_out, outside = {}, {}, {}
    for _, l in ipairs(links) do
        if l.inside == "yes" then
            totals.links_inside = totals.links_inside + 1
            -- A file counts once per including file, however often it is named.
            included_by[l.to] = included_by[l.to] or {}
            included_by[l.to][l.from] = true
            includes_out[l.from] = true
        else
            totals.links_outside = totals.links_outside + 1
            outside[l.to] = outside[l.to] or {}
            outside[l.to][l.from] = true
        end
    end
    -- {{{ local function count_keys
    local function count_keys(t)
        local n = 0
        for _ in pairs(t) do
            n = n + 1
        end
        return n
    end
    -- }}}
    local by_language, by_role, foundations, outside_list, entry_points = {}, {}, {}, {}, {}
    for _, v in pairs(languages) do by_language[#by_language + 1] = v end
    for _, v in pairs(roles) do by_role[#by_role + 1] = v end
    for path, froms in pairs(included_by) do
        foundations[#foundations + 1] = { path = path, included_by = count_keys(froms) }
    end
    for name, froms in pairs(outside) do
        outside_list[#outside_list + 1] = { name = name, used_by = count_keys(froms) }
    end
    -- A C or C++ source file (.c, .cpp) is compiled and linked, never included, so "no
    -- one includes it" says nothing about it being where the program starts.
    -- Those are counted as compile units instead of listed as entry points.
    local compile_units = 0
    for path in pairs(includes_out) do
        if not included_by[path] then
            if path:match("%.c$") or path:match("%.cpp$") or path:match("%.cc$") or path:match("%.cxx$") then
                compile_units = compile_units + 1
            else
                entry_points[#entry_points + 1] = path
            end
        end
    end
    table.sort(entry_points)
    -- Ties are broken by name so the summary is the same every time.
    local more_lines = function(a, b)
        if a.lines ~= b.lines then return a.lines > b.lines end
        return (a.name or a.path) < (b.name or b.path)
    end
    table.sort(by_language, more_lines)
    table.sort(by_role, more_lines)
    return {
        totals = totals,
        by_language = by_language,
        by_role = by_role,
        largest = top(code, 10, more_lines),
        foundations = top(foundations, 10, function(a, b)
            if a.included_by ~= b.included_by then return a.included_by > b.included_by end
            return a.path < b.path
        end),
        entry_points = entry_points,
        compile_units = compile_units,
        outside = top(outside_list, 1e9, function(a, b)
            if a.used_by ~= b.used_by then return a.used_by > b.used_by end
            return a.name < b.name
        end),
    }
end
-- }}}

-- {{{ function summary.text
-- The summary as text for a person.
function summary.text(s)
    local out = {}
    -- {{{ local function add
    local function add(...)
        out[#out + 1] = string.format(...)
    end
    -- }}}
    local t = s.totals
    add("files %d   lines %d   bytes %d   links inside %d   links outside %d",
        t.files, t.lines, t.bytes, t.links_inside, t.links_outside)
    add("")
    add("by language (files, lines):")
    for _, l in ipairs(s.by_language) do
        add("  %-16s %6d %9d", l.name, l.files, l.lines)
    end
    add("")
    add("by role (files, lines):")
    for _, r in ipairs(s.by_role) do
        add("  %-16s %6d %9d", r.name, r.files, r.lines)
    end
    add("")
    add("largest code files (lines):")
    for _, f in ipairs(s.largest) do
        add("  %7d  %s", f.lines, f.path)
    end
    add("")
    add("likely foundations (included by N files):")
    for _, f in ipairs(s.foundations) do
        add("  %4d  %s", f.included_by, f.path)
    end
    add("")
    add("likely entry points (include others, included by none): %d", #s.entry_points)
    add("  (C compile units, linked rather than included, not listed: %d)", s.compile_units)
    for i, p in ipairs(s.entry_points) do
        if i > 15 then
            add("  … and %d more", #s.entry_points - 15)
            break
        end
        add("  %s", p)
    end
    add("")
    add("outside dependencies (used by N files): %d", #s.outside)
    for i, o in ipairs(s.outside) do
        if i > 20 then
            add("  … and %d more", #s.outside - 20)
            break
        end
        add("  %4d  %s", o.used_by, o.name)
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function summary.write
-- Computes and writes survey/summary.txt; returns the text.
function summary.write(survey_folder)
    local text = summary.text(summary.compute(survey_folder))
    fs.write(survey_folder .. "/summary.txt", text)
    return text
end
-- }}}

return summary
