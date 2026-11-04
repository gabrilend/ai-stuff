#!/usr/bin/env luajit
-- reading-walk-pages.lua - The reading walk as linked web pages, and as a
-- one-stop-per-screen view for small OLED displays.
--
-- In plain terms: the same map the terminal walk uses becomes a small website.
-- On the left, every file in reading order; on the right, one file's stops,
-- each with what it is, where it is used (each use a link to the stop that
-- uses it), why it was done this way (only what was written down), its
-- chapter, and its own code with the words coloured by kind. Every stop links
-- to the one before and after, so the site can be read start to finish.
--
-- The small-screen view is one page per stop: black background, only the text
-- lit -- on an OLED screen an unlit pixel costs nothing -- with the summary
-- large and links to the previous and next stop. No scripts on any page; the
-- pages are plain HTML and one stylesheet.
--
-- Pages are written one file per worker job, across one worker per CPU.
--
-- Usage:
--   reading-walk-pages.lua <project>          -- pages from the project's map (built if missing)
--   reading-walk-pages.lua <project> --out=DIR
--   reading-walk-pages.lua ... --map=FILE --workers=N --dir=PATH
--   reading-walk-pages.lua --page-worker LIST MAP OUT   -- internal
--
-- See reading-walk-pages.info.md and issues/065h-the-walk-as-pages.md.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local TARGET, MAP_PATH, OUT_DIR, WORKER_COUNT = nil, nil, nil, nil
local worker_arguments = nil
do
    local index = 1
    while arg[index] do
        local argument = arg[index]
        local dir_value = argument:match("^%-%-dir=(.+)$")
        local map_value = argument:match("^%-%-map=(.+)$")
        local out_value = argument:match("^%-%-out=(.+)$")
        local workers_value = argument:match("^%-%-workers=(%d+)$")
        -- each option sets one setting; the worker mode takes the rest
        if dir_value then DIR = dir_value
        elseif map_value then MAP_PATH = map_value
        elseif out_value then OUT_DIR = out_value
        elseif workers_value then WORKER_COUNT = tonumber(workers_value)
        elseif argument == "--page-worker" then
            worker_arguments = { arg[index + 1], arg[index + 2], arg[index + 3] }
            break
        else TARGET = argument end
        index = index + 1
    end
end
local SCRIPT_PATH = arg[0]
-- }}}

-- {{{ local function fail()
local function fail(message)
    io.stderr:write("reading-walk-pages: ", message, "\n")
    os.exit(1)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function escape()
-- Text made safe to put inside HTML.
local escapes = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
local function escape(text)
    return (tostring(text):gsub('[&<>"]', escapes))
end
-- }}}

-- {{{ local function load_map()
local function load_map(path)
    local chunk, problem = loadfile(path)
    if not chunk then fail("cannot read the map " .. path .. ": " .. tostring(problem)) end
    setfenv(chunk, {})
    return chunk()
end
-- }}}

-- {{{ local function page_name()
-- One page per source file: its path with slashes turned to dashes.
local function page_name(file)
    return (file:gsub("/", "-")) .. ".html"
end
-- }}}

-- {{{ local function stop_for_line()
-- The stop whose span holds a file's line, for linking a use to the stop that
-- makes it; the innermost (latest-starting) one when folds nest.
local function stop_index_by_file(map)
    local by_file = {}
    for _, stop in ipairs(map.stops) do
        local list = by_file[stop.file] or {}
        list[#list + 1] = stop
        by_file[stop.file] = list
    end
    return function(file, line)
        local best = nil
        for _, stop in ipairs(by_file[file] or {}) do
            if line >= stop.line and line <= stop.end_line then best = stop end
        end
        return best
    end
end
-- }}}

-- {{{ local function highlight()
-- One line of Lua coloured by kind: comments, strings, numbers, keywords. A
-- plain scan, not a parser: good enough to read by, and it never reorders or
-- drops a character.
local keywords = {}
for word in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do
    keywords[word] = true
end
local function highlight(line)
    local out, position = {}, 1
    while position <= #line do
        local rest = line:sub(position)
        local comment = rest:match("^%-%-.*")
        local quoted = rest:match('^"[^"]*"') or rest:match("^'[^']*'")
        local number = rest:match("^%d[%w%.]*")
        local word = rest:match("^[%a_][%w_]*")
        -- each kind of token is coloured by its class; anything else passes as is
        if comment then
            out[#out + 1] = '<span class="c">' .. escape(comment) .. "</span>"
            position = #line + 1
        elseif quoted then
            out[#out + 1] = '<span class="s">' .. escape(quoted) .. "</span>"
            position = position + #quoted
        elseif number then
            out[#out + 1] = '<span class="n">' .. escape(number) .. "</span>"
            position = position + #number
        elseif word then
            out[#out + 1] = keywords[word] and ('<span class="k">' .. word .. "</span>") or word
            position = position + #word
        else
            out[#out + 1] = escape(rest:sub(1, 1))
            position = position + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ local STYLE
-- One stylesheet for every page. Colours are tokens on :root, redefined for a
-- dark preference, so the pages follow the reader's light or dark setting.
local STYLE = [[
:root { --bg: #fbfaf7; --fg: #1d1d1b; --dim: #6b6a65; --line: #e2dfd8; --accent: #2f5d8a;
        --code-bg: #f1efe9; --k: #8a3a2f; --s: #2f6b3a; --c: #7a7770; --n: #6a4a8a; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #151514; --fg: #e8e6e1; --dim: #9a978f; --line: #2c2b28; --accent: #8fb6dc;
          --code-bg: #1e1d1b; --k: #e39a8c; --s: #9ccf9f; --c: #8a877f; --n: #c3a6e6; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.55 Georgia, serif; }
a { color: var(--accent); }
.layout { display: flex; min-height: 100vh; }
nav { width: 280px; flex: none; border-right: 1px solid var(--line); padding: 16px; font: 13px/1.5 system-ui, sans-serif; }
nav ol { padding-left: 20px; margin: 0; }
nav .here { font-weight: bold; }
main { flex: 1; min-width: 0; padding: 16px 32px 64px; max-width: 900px; }
.stop { border-top: 1px solid var(--line); padding-top: 20px; margin-top: 28px; }
.stop h2 { margin: 0; font-size: 22px; }
.meta { color: var(--dim); font: 13px/1.5 system-ui, sans-serif; }
.summary { font-style: italic; }
.note { color: var(--dim); font-size: 14px; }
pre { background: var(--code-bg); padding: 12px; overflow-x: auto; font: 13px/1.45 ui-monospace, monospace; }
.k { color: var(--k); } .s { color: var(--s); } .c { color: var(--c); } .n { color: var(--n); }
.steps { font: 13px system-ui, sans-serif; }
blockquote { margin: 8px 0; padding-left: 12px; border-left: 3px solid var(--line); }
@media (max-width: 760px) { .layout { display: block; } nav { width: auto; border-right: 0; border-bottom: 1px solid var(--line); } main { padding: 16px; } }
]]
-- }}}

-- {{{ local OLED_STYLE
-- The small-screen view: pure black, only text lit, large summary.
local OLED_STYLE = [[
html, body { margin: 0; background: #000; color: #d8d8d8; font: 15px/1.4 system-ui, sans-serif; }
body { padding: 12px; }
.name { color: #fff; font-size: 20px; font-weight: bold; }
.summary { color: #fff; font-size: 18px; margin: 12px 0; }
.meta { color: #777; font-size: 12px; }
a { color: #8fb6dc; text-decoration: none; font-size: 18px; margin-right: 20px; }
]]
-- }}}

-- {{{ local function file_list()
-- The files in reading order, each with its first stop.
local function file_list(map)
    local files, seen = {}, {}
    for _, stop in ipairs(map.stops) do
        if not seen[stop.file] then
            seen[stop.file] = true
            files[#files + 1] = { file = stop.file, first = stop.index }
        end
    end
    return files
end
-- }}}

-- {{{ local function render_file_page()
-- One source file's page: the navigation, then each of its stops.
local function render_file_page(map, file, source_lines, find_stop)
    local stops = map.stops
    local parts = {}
    local function put(text) parts[#parts + 1] = text end
    put("<!doctype html>\n<!-- Made by delta-version/scripts/reading-walk-pages.lua from the reading-walk map of " ..
        escape(map.project_name) .. ", so the walk can be read in a browser (issue 065h). -->\n")
    put('<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    put("<title>" .. escape(map.project_name) .. " walk</title>")
    put('<link rel="stylesheet" href="walk.css"></head><body><div class="layout"><nav>')
    put('<p><a href="index.html">' .. escape(map.project_name) .. '</a> &middot; <a href="oled/1.html">small screen</a></p><ol>')
    for _, entry in ipairs(file_list(map)) do
        local class = (entry.file == file) and ' class="here"' or ""
        put("<li" .. class .. '><a href="' .. page_name(entry.file) .. '">' .. escape(entry.file) .. "</a></li>")
    end
    put("</ol></nav><main><h1>" .. escape(file) .. "</h1>")
    for _, stop in ipairs(stops) do
        if stop.file == file then
            put('<section class="stop" id="stop-' .. stop.index .. '">')
            put("<h2>" .. escape(stop.name) .. "</h2>")
            put('<p class="meta">stop ' .. stop.index .. " of " .. #stops .. " &middot; " .. stop.kind ..
                " &middot; line " .. stop.line .. " &middot; chapter: " .. escape(stop.chapter.date) .. " " ..
                escape(stop.chapter.subject) .. "</p>")
            put('<p class="summary">' .. escape(stop.summary) .. "</p>")
            -- the description says where it came from when it is not the page
            if stop.description_source == "info.md" then
                put("<p>" .. escape(stop.description) .. "</p>")
            elseif stop.description_source == "source comment" then
                put("<p>" .. escape(stop.description) .. '</p><p class="note">from the source comment: the .info.md page has no entry for this</p>')
            else
                put('<p class="note">nothing describes this: no .info.md entry and no comment</p>')
            end
            put("<h3>Where it is used</h3>")
            if #stop.uses == 0 then put('<p class="note">not used anywhere in the source</p>') else
                put("<ul>")
                for _, use in ipairs(stop.uses) do
                    local user = find_stop(use.file, use.line)
                    local target = user and (page_name(user.file) .. "#stop-" .. user.index) or page_name(use.file)
                    local label = user and user.name or use.file
                    put('<li><a href="' .. target .. '">' .. escape(label) .. "</a> &middot; " ..
                        escape(use.file) .. ":" .. use.line .. " <code>" .. escape(use.text) .. "</code></li>")
                end
                put("</ul>")
            end
            put("<h3>Why it was done this way</h3>")
            if #stop.alternatives == 0 then
                put('<p class="note">no alternative was recorded here — this choice was not written down</p>')
            else
                for _, reason in ipairs(stop.alternatives) do
                    put('<p class="meta">' .. escape(reason.source) .. ":" .. reason.line .. "</p><blockquote>" ..
                        escape(reason.text) .. "</blockquote>")
                end
            end
            put("<h3>Its code</h3><pre><code>")
            for number = stop.line, stop.end_line do
                put(string.format('<span class="c">%5d</span>  ', number) .. highlight(source_lines[number] or "") .. "\n")
            end
            put("</code></pre>")
            local previous, following = stops[stop.index - 1], stops[stop.index + 1]
            put('<p class="steps">')
            if previous then put('<a href="' .. page_name(previous.file) .. "#stop-" .. previous.index .. '">&larr; ' .. escape(previous.name) .. "</a> ") end
            if following then put('&nbsp; <a href="' .. page_name(following.file) .. "#stop-" .. following.index .. '">' .. escape(following.name) .. " &rarr;</a>") end
            put("</p></section>")
        end
    end
    put("</main></div></body></html>\n")
    return table.concat(parts)
end
-- }}}

-- {{{ local function render_oled_page()
local function render_oled_page(map, stop)
    local stops = map.stops
    local parts = {
        "<!doctype html>\n<!-- Made by delta-version/scripts/reading-walk-pages.lua: one reading-walk stop for a small OLED screen (issue 065h). -->\n",
        '<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>stop " .. stop.index .. "</title><style>" .. OLED_STYLE .. "</style></head><body>",
        '<div class="meta">' .. stop.index .. " / " .. #stops .. " &middot; " .. escape(stop.file) .. "</div>",
        '<div class="name">' .. escape(stop.name) .. "</div>",
        '<div class="summary">' .. escape(stop.summary) .. "</div><div>",
    }
    if stops[stop.index - 1] then parts[#parts + 1] = '<a href="' .. (stop.index - 1) .. '.html" accesskey="b">&larr; back</a>' end
    if stops[stop.index + 1] then parts[#parts + 1] = '<a href="' .. (stop.index + 1) .. '.html" accesskey="n">next &rarr;</a>' end
    parts[#parts + 1] = "</div></body></html>\n"
    return table.concat(parts)
end
-- }}}

-- {{{ local function write_file()
local function write_file(path, text)
    local handle = io.open(path, "w")
    if not handle then fail("cannot write " .. path) end
    handle:write(text)
    handle:close()
end
-- }}}

-- {{{ local function run_page_worker()
-- One worker: its share of jobs, each "file <path>" (a source file's page) or
-- "oled <index>" (one small-screen page). Ends by writing a finished marker.
local function run_page_worker(list_path, map_path, out_dir)
    local map = load_map(map_path)
    local find_stop = stop_index_by_file(map)
    local jobs = {
        file = function(file)
            local lines = {}
            local handle = io.open(map.project .. "/" .. file, "r")
            if not handle then fail("the source file is gone: " .. file) end
            for line in handle:lines() do lines[#lines + 1] = line end
            handle:close()
            write_file(out_dir .. "/" .. page_name(file), render_file_page(map, file, lines, find_stop))
        end,
        oled = function(index)
            write_file(out_dir .. "/oled/" .. index .. ".html", render_oled_page(map, map.stops[tonumber(index)]))
        end,
    }
    for line in io.lines(list_path) do
        local kind, value = line:match("^(%w+) (.*)$")
        jobs[kind](value)
    end
    write_file(list_path .. ".finished", "finished\n")
end
-- }}}

-- {{{ local function build_pages()
local function build_pages()
    if not MAP_PATH then
        if not TARGET then fail("usage: reading-walk-pages.lua <project> [--out=DIR] [--map=FILE]") end
        local project = TARGET:gsub("/+$", "")
        local name = project:match("([^/]+)$")
        MAP_PATH = DIR .. "/tmp/shared-memory/reading-walk/" .. name .. ".map.lua"
        local present = io.open(MAP_PATH, "r")
        if present then present:close() else
            local status = os.execute(string.format("luajit %s %s --dir=%s >&2",
                shell_quote(DIR .. "/scripts/reading-walk-map.lua"), shell_quote(project), shell_quote(DIR)))
            if status ~= 0 and status ~= true then fail("the map builder failed") end
        end
    end
    local map = load_map(MAP_PATH)
    OUT_DIR = OUT_DIR or (DIR .. "/tmp/shared-memory/reading-walk/" .. map.project_name .. "-pages")
    os.execute("mkdir -p " .. shell_quote(OUT_DIR .. "/oled"))

    -- the shared pieces: stylesheet and front page
    write_file(OUT_DIR .. "/walk.css", "/* Made by delta-version/scripts/reading-walk-pages.lua: the walk's one stylesheet. */\n" .. STYLE)
    local files = file_list(map)
    local front = { "<!doctype html>\n<!-- Made by delta-version/scripts/reading-walk-pages.lua: the front page of the walk (issue 065h). -->\n",
        '<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>" .. escape(map.project_name) .. " walk</title>",
        '<link rel="stylesheet" href="walk.css"></head><body><main><h1>' .. escape(map.project_name) .. "</h1>",
        "<p>" .. #map.stops .. " stops in " .. #files .. " files, in the order the project is meant to be read. " ..
        "Reading every stop, or its summary, is a complete reading.</p>",
        '<p><a href="' .. page_name(map.stops[1].file) .. '#stop-1">Begin at the first stop &rarr;</a> &middot; ' ..
        '<a href="oled/1.html">small screen</a></p><ol>' }
    for _, entry in ipairs(files) do
        front[#front + 1] = '<li><a href="' .. page_name(entry.file) .. '">' .. escape(entry.file) .. "</a></li>"
    end
    front[#front + 1] = "</ol></main></body></html>\n"
    write_file(OUT_DIR .. "/index.html", table.concat(front))

    -- the pages, shared round-robin across workers
    local jobs = {}
    for _, entry in ipairs(files) do jobs[#jobs + 1] = "file " .. entry.file end
    for index = 1, #map.stops do jobs[#jobs + 1] = "oled " .. index end
    local pipe = io.popen("nproc")
    local count = WORKER_COUNT or tonumber(pipe:read("*l"))
    pipe:close()
    if count > #jobs then count = #jobs end
    local scratch = DIR .. "/tmp/shared-memory/reading-walk/pages-run-" .. os.time()
    os.execute("mkdir -p " .. shell_quote(scratch))
    local commands, lists = {}, {}
    for worker = 1, count do
        local share = {}
        for index = worker, #jobs, count do share[#share + 1] = jobs[index] end
        lists[worker] = scratch .. "/share-" .. worker .. ".list"
        write_file(lists[worker], table.concat(share, "\n") .. "\n")
        commands[#commands + 1] = string.format("luajit %s --page-worker %s %s %s &",
            shell_quote(SCRIPT_PATH), shell_quote(lists[worker]), shell_quote(MAP_PATH), shell_quote(OUT_DIR))
    end
    os.execute("bash -c " .. shell_quote(table.concat(commands, "\n") .. "\nwait"))
    for _, list in ipairs(lists) do
        local done = io.open(list .. ".finished", "r")
        if not done then fail("a page worker stopped part-way: " .. list) end
        done:close()
    end
    io.write(string.format("pages for %s: %d file pages, %d small-screen pages\n  open %s/index.html\n",
        map.project_name, #files, #map.stops, OUT_DIR))
end
-- }}}

-- {{{ main
if worker_arguments then run_page_worker(worker_arguments[1], worker_arguments[2], worker_arguments[3])
else build_pages() end
-- }}}
