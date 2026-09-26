-- 029-the-survey.lua
--
-- Reading a whole source across every core. The walk's path list is dealt
-- out like cards, one slice per hardware thread (entry 1 to slice 1, entry 2
-- to slice 2, …), so large files that sit together in one folder are spread
-- across threads instead of landing on one. Each worker reads its slice
-- (language, role, lines, bytes, include lines) and hands back its rows as
-- escaped text, each row prefixed with the entry's number in the walk; the
-- gatherer puts every row back in walk order — path order — and writes
-- survey/files.tsv and survey/links.tsv. The tables come out byte-identical
-- however many threads ran (tests/032 holds this).
--
-- Threads share no Lua state: a worker is given plain strings only (the
-- project folder, the source root, its slice, every path) and loads the
-- language table and scanners for itself.
--
-- A file row (docs/002): path, language, role, lines, bytes
-- A link row: from, to, kind, inside

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")
local walk = require("026-the-walk")

local survey = {}

survey.FILE_HEADER = { "path", "language", "role", "lines", "bytes" }
survey.LINK_HEADER = { "from", "to", "kind", "inside" }

-- {{{ local function read_slice
-- The worker's whole job, run inside a thread (or on the calling thread when
-- one thread is asked for). Must use no upvalues: everything it needs comes
-- in as arguments or through require.
local function read_slice(project_dir, root, slice_text, all_paths_text)
    package.path = project_dir .. "/src/?.lua;" .. package.path
    local languages = require("027-the-language-table")
    local includes = require("028-include-lines")
    local tables = require("014-text-tables")
    local all_paths = {}
    for path in all_paths_text:gmatch("[^\n]+") do
        all_paths[path] = true
    end
    local file_lines, link_lines = {}, {}
    for entry in slice_text:gmatch("[^\n]+") do
        local number, kind, path = entry:match("^(%d+) (%a) (.*)$")
        path = tables.unescape(path)
        -- Every row carries its entry number so the gatherer can restore
        -- walk order: "number<TAB>row".
        local tag = number .. "\t"
        if kind == "l" then
            -- A link is recorded, never followed.
            file_lines[#file_lines + 1] = tag .. tables.row_line({ path, "link", "link", 0, 0 })
        else
            local file = io.open(root .. "/" .. path, "rb")
            if not file then
                error("survey: cannot open " .. path)
            end
            local head = file:read(8192) or ""
            local row = languages.classify(path, head)
            local bytes, lines
            if row.role == "binary" then
                -- A binary file's lines mean nothing; its size is enough.
                bytes = file:seek("end")
                lines = 0
                file:close()
            else
                local rest = file:read("*a") or ""
                file:close()
                local text = head .. rest
                bytes = #text
                -- Counted with a plain search: gsub would build a copy of the
                -- whole file just to count, and on a large C++ tree that copy
                -- was nearly all of the survey's time.
                lines = 0
                local at = text:find("\n", 1, true)
                while at do
                    lines = lines + 1
                    at = text:find("\n", at + 1, true)
                end
                if row.scanner then
                    for _, found in ipairs(includes.scan(row.scanner, text)) do
                        local to, inside
                        if found.outside then
                            to, inside = found.name, "no"
                        else
                            to, inside = includes.resolve(path, found.name, row.scanner, all_paths)
                        end
                        link_lines[#link_lines + 1] = tag .. tables.row_line({ path, to, found.kind, inside })
                    end
                end
            end
            file_lines[#file_lines + 1] = tag .. tables.row_line({ path, row.language, row.role, lines, bytes })
        end
    end
    local file_text = table.concat(file_lines, "\n")
    local link_text = table.concat(link_lines, "\n")
    return file_text, link_text
end
-- }}}

-- {{{ local function load_thread_library
local function load_thread_library(project)
    local ok, effil = pcall(require, "effil")
    -- One thread because threads were missing would be a silent fallback.
    if not ok then
        error("survey: the thread library could not be loaded from " .. project.thread_library_build
            .. ": " .. tostring(effil))
    end
    return effil
end
-- }}}

-- {{{ local function slices_of
-- Deals the entries into at most `count` slices, as text: one line per entry,
-- "number f path" or "number l path", the path escaped so no name can break
-- a line.
local function slices_of(entries, count)
    count = math.max(1, math.min(count, #entries))
    local lines = {}
    for s = 1, count do
        lines[s] = {}
    end
    for i, e in ipairs(entries) do
        local s = (i - 1) % count + 1
        local slice = lines[s]
        slice[#slice + 1] = i .. (e.kind == "link" and " l " or " f ") .. text_tables.escape(e.path)
    end
    local slices = {}
    for s = 1, count do
        if #lines[s] > 0 then
            slices[#slices + 1] = table.concat(lines[s], "\n")
        end
    end
    return slices
end
-- }}}

-- {{{ local function in_walk_order
-- Puts tagged rows ("number<TAB>row") from every slice back in walk order.
-- Rows sharing a number (one file's links) keep the order they were found in.
local function in_walk_order(parts)
    local by_number = {}
    local numbers = {}
    for _, part in ipairs(parts) do
        for tagged in part:gmatch("[^\n]+") do
            local number, row = tagged:match("^(%d+)\t(.*)$")
            number = tonumber(number)
            if not by_number[number] then
                by_number[number] = {}
                numbers[#numbers + 1] = number
            end
            local rows = by_number[number]
            rows[#rows + 1] = row
        end
    end
    table.sort(numbers)
    local out = {}
    for _, number in ipairs(numbers) do
        for _, row in ipairs(by_number[number]) do
            out[#out + 1] = row
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function survey.read_source
-- Reads the whole source. Returns file text and link text (escaped rows,
-- newline-joined, path order) and the number of threads used.
-- `threads` forces a count; nil means every hardware thread.
function survey.read_source(project, root, threads, limit)
    local entries = walk.list(root, walk.SURVEY_SKIPS, limit or walk.DEFAULT_FILE_LIMIT)
    local all = {}
    for i, e in ipairs(entries) do
        all[i] = e.path
    end
    local all_text = table.concat(all, "\n")
    local effil = load_thread_library(project)
    threads = threads or effil.hardware_threads()
    local slices = slices_of(entries, threads)
    local file_parts, link_parts = {}, {}
    if threads == 1 then
        -- The same worker code on the calling thread, for comparison.
        for i, slice in ipairs(slices) do
            file_parts[i], link_parts[i] = read_slice(project.dir, root, slice, all_text)
        end
    else
        local runners = {}
        for i, slice in ipairs(slices) do
            runners[i] = effil.thread(read_slice)(project.dir, root, slice, all_text)
        end
        for i, runner in ipairs(runners) do
            local status, err = runner:wait()
            if status ~= "completed" then
                error("survey: a worker stopped (" .. tostring(status) .. "): " .. tostring(err))
            end
            file_parts[i], link_parts[i] = runner:get()
        end
    end
    return in_walk_order(file_parts), in_walk_order(link_parts), #slices, #entries
end
-- }}}

-- {{{ local function write_rows_text
-- Writes a table file from already-escaped row text.
local function write_rows_text(path, header, rows_text)
    local body = "#" .. table.concat(header, "\t") .. "\n"
    if rows_text ~= "" then
        body = body .. rows_text .. "\n"
    end
    fs.write(path, body)
end
-- }}}

-- {{{ function survey.run
-- Surveys a case's source into its survey/ folder. Returns counts.
function survey.run(project, case_record, threads)
    local file_text, link_text, used, count = survey.read_source(project, case_record.source, threads)
    fs.make_folder(case_record.survey)
    write_rows_text(case_record.survey .. "/files.tsv", survey.FILE_HEADER, file_text)
    write_rows_text(case_record.survey .. "/links.tsv", survey.LINK_HEADER, link_text)
    local _, link_count = link_text:gsub("[^\n]+", "")
    return { files = count, links = link_count, threads = used }
end
-- }}}

return survey
