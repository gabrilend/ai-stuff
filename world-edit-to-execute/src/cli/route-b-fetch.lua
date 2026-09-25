#!/usr/bin/env luajit
-- route-b-fetch.lua - fetch the stock values Liquipedia publishes, for Route B's cross-check
--
-- In plain terms: the project reads every stock number from the player's own
-- install (Route A). Issue 112 wants each checked against an independent
-- published source. This tool fetches the Warcraft III wiki's unit,
-- building, spell and item pages (their infoboxes hold the numbers), once,
-- gently, and keeps them on disk; src/cli/route-b-report.lua compares them.
--
-- Phases, each resumable from the cache (nothing cached is fetched again):
--   discover      the pages using each infobox template (one request each,
--                 continued if a list is longer than 500)
--   current       today's revision of every page, 50 pages per request
--   old <list>    the revision as it stood when 1.29.2 was current (the last
--                 before 2018-08-08, when 1.30 came out) for each page named
--                 in <list> (one per line), one page per request (the API
--                 allows no more for old revisions)
--
-- Gentle means (the owner, 2026-09-25): one request every 10 seconds, give or
-- take one to two seconds at random ("+/- 1-2 seconds for each request"),
-- across runs (the last request's time is kept in the cache); compressed; a
-- User-Agent naming only the tool; cached on disk beside the installs
-- (wc3-installs/external-values, a link ignored by git; "Then let's cache it
-- on disk").
--
-- The text is Liquipedia's (CC BY-SA 3.0): kept in its own folder, used only
-- to check Route A, never to fill a table, never committed.
--
-- Usage:
--   luajit src/cli/route-b-fetch.lua [--dir DIR] discover | current | old <list file> | status
--
-- Issue: issues/112e-route-b-published-values-cross-check.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end

local CACHE = DIR .. "/wc3-installs/external-values"
local API = "https://liquipedia.net/warcraft/api.php"
local USER_AGENT = "world-edit-to-execute stock values cross-check"
local SPACING, JITTER = 10, 2          -- seconds: 10, give or take up to 2
local BEFORE = "2018-08-08T00:00:00Z"  -- 1.30.0's release: pages as they stood under 1.29.2
local TEMPLATES = { "Infobox unit", "Infobox building", "Infobox spell", "Infobox item" }

math.randomseed(os.time())

-- {{{ local function shell_quote
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function url_encode
local function url_encode(s)
    return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end
-- }}}

-- {{{ local function safe_name
-- A page title as a file name ("Knight", "Orb of Fire" -> "Orb_of_Fire").
local function safe_name(title)
    return (title:gsub("[^%w%-%._]", "_"))
end
-- }}}

-- {{{ local function wait_turn
-- Waits until the spacing since the last request (any run) has passed: 10
-- seconds plus or minus a random 1-2, then records this request's time.
local function wait_turn()
    local stamp = CACHE .. "/.last_request"
    local f = io.open(stamp, "r")
    if f then
        local last = tonumber(f:read("*l")) or 0
        f:close()
        local sign = math.random(0, 1) == 0 and -1 or 1
        local gap = SPACING + sign * (1 + math.random() )   -- 8-9 or 11-12 seconds
        local wait = last + gap - os.time()
        if wait > 0 then
            os.execute(string.format("sleep %.2f", wait))
        end
    end
    local g = assert(io.open(stamp, "w"))
    g:write(os.time(), "\n")
    g:close()
end
-- }}}

-- {{{ local function get
-- One API request; returns the reply's text (JSON).
local function get(query)
    wait_turn()
    local out = CACHE .. "/.response.json"
    local cmd = "curl --fail --silent --show-error --compressed -A " .. shell_quote(USER_AGENT)
        .. " -o " .. shell_quote(out) .. " " .. shell_quote(API .. "?format=json&formatversion=2&" .. query)
    local ok = os.execute(cmd)
    if ok ~= 0 and ok ~= true then
        error("the request failed: " .. query)
    end
    local f = assert(io.open(out, "r"))
    local body = f:read("*a")
    f:close()
    os.remove(out)
    return body
end
-- }}}

-- {{{ JSON reading (only what these replies need)
local function json_string_at(s, i)
    local out, j = {}, i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then error("unterminated string in the reply") end
        if c == '"' then return table.concat(out), j + 1 end
        if c == "\\" then
            local e = s:sub(j + 1, j + 1)
            if e == "u" then
                local code = tonumber(s:sub(j + 2, j + 5), 16)
                j = j + 6
                if code >= 0xD800 and code <= 0xDBFF and s:sub(j, j + 1) == "\\u" then
                    code = 0x10000 + (code - 0xD800) * 0x400 + (tonumber(s:sub(j + 2, j + 5), 16) - 0xDC00)
                    j = j + 6
                end
                if code < 0x80 then out[#out + 1] = string.char(code)
                elseif code < 0x800 then out[#out + 1] = string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
                elseif code < 0x10000 then out[#out + 1] = string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
                else out[#out + 1] = string.char(0xF0 + math.floor(code / 262144), 0x80 + math.floor(code / 4096) % 64, 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64) end
            else
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                out[#out + 1] = map[e] or e
                j = j + 2
            end
        else
            out[#out + 1] = c
            j = j + 1
        end
    end
end
-- Every value of "key":"..." in order.
local function strings_of(body, key)
    local out, pos = {}, 1
    local pat = '"' .. key .. '":'
    while true do
        local k = body:find(pat, pos, true)
        if not k then break end
        local q = body:find('"', k + #pat, true)
        if q ~= k + #pat then pos = k + #pat else
            local v, after = json_string_at(body, q)
            out[#out + 1] = v
            pos = after
        end
    end
    return out
end
-- }}}

-- {{{ local function write_file
local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ local function read_lines
local function read_lines(path)
    local list = {}
    local f = io.open(path, "r")
    if not f then return list end
    for line in f:lines() do if line ~= "" then list[#list + 1] = line end end
    f:close()
    return list
end
-- }}}

-- {{{ phase discover
local function discover()
    for _, template in ipairs(TEMPLATES) do
        local file = CACHE .. "/pages." .. safe_name(template) .. ".txt"
        if io.open(file, "r") then
            print("  " .. template .. ": cached")
        else
            local titles, cont = {}, nil
            repeat
                local body = get("action=query&list=embeddedin&einamespace=0&eilimit=500&eititle="
                    .. url_encode("Template:" .. template) .. (cont and ("&eicontinue=" .. url_encode(cont)) or ""))
                for _, t in ipairs(strings_of(body, "title")) do titles[#titles + 1] = t end
                cont = strings_of(body, "eicontinue")[1]
            until not cont
            table.sort(titles)
            write_file(file, table.concat(titles, "\n") .. "\n")
            print(string.format("  %s: %d pages", template, #titles))
        end
    end
end
-- }}}

-- {{{ phase current / old
-- A page's cached revision: current/<name>.wikitext or old/<name>.wikitext,
-- with a line of metadata in <name>.meta (timestamp, revision id).
local function save_page(kind, title, content, timestamp, revid)
    os.execute("mkdir -p " .. shell_quote(CACHE .. "/" .. kind))
    local base = CACHE .. "/" .. kind .. "/" .. safe_name(title)
    write_file(base .. ".wikitext", content)
    write_file(base .. ".meta", string.format("%s\t%s\t%s\thttps://liquipedia.net/warcraft/%s\tCC BY-SA 3.0\t%s\n",
        title, timestamp or "", revid or "", title:gsub(" ", "_"), os.date("!%Y-%m-%dT%H:%M:%SZ")))
end
local function cached(kind, title)
    local f = io.open(CACHE .. "/" .. kind .. "/" .. safe_name(title) .. ".meta", "r")
    if f then f:close() return true end
    return false
end

-- Splits a query reply into its pages: {title, content, timestamp, revid}.
local function pages_of(body)
    local out, pos = {}, body:find('"pages"', 1, true) or 1
    while true do
        local t = body:find('"title":', pos, true)
        if not t then break end
        local title, after = json_string_at(body, body:find('"', t + 8, true))
        local next_t = body:find('"title":', after, true) or #body + 1
        local seg = body:sub(after, next_t - 1)
        local page = { title = title }
        local c = seg:find('"content":', 1, true)
        if c then page.content = json_string_at(seg, seg:find('"', c + 10, true)) end
        page.timestamp = seg:match('"timestamp":"([^"]+)"')
        page.revid = seg:match('"revid":(%d+)')
        out[#out + 1] = page
        pos = after
    end
    return out
end

local function current()
    local all = {}
    for _, template in ipairs(TEMPLATES) do
        for _, t in ipairs(read_lines(CACHE .. "/pages." .. safe_name(template) .. ".txt")) do all[#all + 1] = t end
    end
    local wanted = {}
    for _, t in ipairs(all) do if not cached("current", t) then wanted[#wanted + 1] = t end end
    print(string.format("  %d pages listed, %d to fetch, %d requests", #all, #wanted, math.ceil(#wanted / 50)))
    for first = 1, #wanted, 50 do
        local batch = {}
        for i = first, math.min(first + 49, #wanted) do batch[#batch + 1] = wanted[i] end
        local body = get("action=query&prop=revisions&rvprop=content|timestamp|ids&rvslots=main&titles="
            .. url_encode(table.concat(batch, "|")))
        for _, page in ipairs(pages_of(body)) do
            if page.content then save_page("current", page.title, page.content, page.timestamp, page.revid) end
        end
        print(string.format("  fetched %d-%d", first, first + #batch - 1))
    end
end

local function old(list_file)
    local titles = read_lines(list_file)
    local todo = {}
    for _, t in ipairs(titles) do if not cached("old", t) then todo[#todo + 1] = t end end
    print(string.format("  %d pages listed, %d to fetch (one request each)", #titles, #todo))
    for i, t in ipairs(todo) do
        local body = get("action=query&prop=revisions&rvprop=content|timestamp|ids&rvslots=main&rvlimit=1&rvdir=older&rvstart="
            .. url_encode(BEFORE) .. "&titles=" .. url_encode(t))
        local page = pages_of(body)[1]
        if page and page.content then
            save_page("old", t, page.content, page.timestamp, page.revid)
        else
            -- No revision before 1.30: the page was written later. Recorded so it isn't asked again.
            save_page("old", t, "", "none before " .. BEFORE, "")
        end
        if i % 10 == 0 or i == #todo then print(string.format("  %d of %d", i, #todo)) end
    end
end
-- }}}

-- {{{ main
os.execute("mkdir -p " .. shell_quote(CACHE .. "/"))
local probe = io.open(CACHE .. "/.", "r")
if not probe then
    error("no " .. CACHE .. ": create it as a link to a folder beside the installs (see wc3-installs/README.md)")
end
probe:close()

local phase = arg[1]
if phase == "discover" then discover()
elseif phase == "current" then current()
elseif phase == "old" then
    if not arg[2] then error("old needs a file listing the pages, one per line") end
    old(arg[2])
elseif phase == "status" then
    for _, template in ipairs(TEMPLATES) do
        print(string.format("  %-18s %d pages listed", template, #read_lines(CACHE .. "/pages." .. safe_name(template) .. ".txt")))
    end
    local n_cur = tonumber(io.popen("ls '" .. CACHE .. "/current' 2>/dev/null | grep -c meta"):read("*l")) or 0
    local n_old = tonumber(io.popen("ls '" .. CACHE .. "/old' 2>/dev/null | grep -c meta"):read("*l")) or 0
    print(string.format("  current revisions cached: %d; old revisions cached: %d", n_cur, n_old))
else
    print("Usage: luajit src/cli/route-b-fetch.lua [--dir DIR] discover | current | old <list file> | status")
    os.exit(phase == "--help" and 0 or 1)
end
-- }}}
