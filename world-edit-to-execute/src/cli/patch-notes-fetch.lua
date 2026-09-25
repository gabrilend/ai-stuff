#!/usr/bin/env luajit
-- patch-notes-fetch.lua - fetch patch notes for the Warcraft III versions the project doesn't read
--
-- In plain terms: the balance history page shows every version the project
-- reads from the game's own files. For the others (classic versions with no
-- patch program found, and the later versions the project leaves alone on
-- principle) it can show the patch notes Liquipedia's Warcraft III wiki
-- publishes, as text only, marked as not supported. This tool fetches those
-- pages once, gently, and keeps them on disk; it never fetches a page it
-- already has.
--
-- Gentle means: every page in as few requests as the API allows (up to 50
-- titles each; about one or two in total), at least 30 seconds apart,
-- compressed, through the standard API only, with a User-Agent naming the tool
-- and nothing about the person running it (the owner: "No sense giving them
-- more info than they already have"; "let's be sure not to 'abuse' their
-- tools").
--
-- The text is Liquipedia's, CC BY-SA 3.0: kept in its own folder beside the
-- installs (wc3-installs/external-notes, a link ignored by git), never mixed
-- into the project's data or committed.
--
-- Usage:
--   luajit src/cli/patch-notes-fetch.lua [--dir DIR] [--list]
--     --list   show which versions are cached and which aren't; fetch nothing
--
-- Issue: issues/completed/115b-notes-for-versions-we-dont-read.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end

local CACHE = DIR .. "/wc3-installs/external-notes"
local API = "https://liquipedia.net/warcraft/api.php"
local USER_AGENT = "world-edit-to-execute patch notes fetch"
local SECONDS_BETWEEN_REQUESTS = 30

-- {{{ VERSIONS
-- Versions the project doesn't read from the game's files, each with its
-- Liquipedia page title (the wiki names pages "Patch <version>"). Classic
-- versions with no patch program found, then the later versions left alone
-- on principle (docs/versions-we-leave-alone.md).
local VERSIONS = {
    "1.10", "1.12", "1.13", "1.14", "1.15", "1.16", "1.17", "1.18",
    "1.21a", "1.21b", "1.22a", "1.23a", "1.27a",
    "1.28", "1.28.0", "1.28.1", "1.28.2", "1.28.3", "1.28.5", "1.29.0",
    "1.30.0", "1.30.1", "1.30.2", "1.30.3", "1.30.4", "1.31.0", "1.31.1",
    "1.32.0", "1.32.1", "1.32.2", "1.32.3", "1.32.4", "1.32.5", "1.32.6", "1.32.7", "1.32.8", "1.32.9", "1.32.10",
    "1.33.0", "1.34.0", "1.35.0", "1.36.0", "1.36.1", "1.36.2",
    "2.0.0", "2.0.1", "2.0.2", "2.0.3",
}
-- }}}

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

-- {{{ local function cached_file
local function cached_file(version)
    return CACHE .. "/" .. version .. ".wikitext"
end
-- }}}

-- {{{ local function is_cached
local function is_cached(version)
    local f = io.open(cached_file(version), "r")
    if f then f:close() return true end
    local g = io.open(CACHE .. "/" .. version .. ".missing", "r")
    if g then g:close() return true end
    return false
end
-- }}}

-- {{{ local function request
-- One API request for up to 50 titles' current text. Returns the raw JSON.
local function request(titles)
    -- The spacing holds across runs too: the last request's time is kept in
    -- the cache, and a new one waits out the rest of the interval.
    local stamp = CACHE .. "/.last_request"
    local f0 = io.open(stamp, "r")
    if f0 then
        local last = tonumber(f0:read("*l")) or 0
        f0:close()
        local wait = last + SECONDS_BETWEEN_REQUESTS - os.time()
        if wait > 0 then
            print(string.format("waiting %d seconds since the last request", wait))
            os.execute("sleep " .. wait)
        end
    end
    local g0 = assert(io.open(stamp, "w")); g0:write(os.time(), "\n"); g0:close()
    local url = API .. "?action=query&format=json&formatversion=2&redirects=1&prop=revisions"
        .. "&rvprop=content&rvslots=main&titles=" .. url_encode(table.concat(titles, "|"))
    local out = CACHE .. "/.response.json"
    local cmd = "curl --fail --silent --show-error --compressed -A " .. shell_quote(USER_AGENT)
        .. " -o " .. shell_quote(out) .. " " .. shell_quote(url)
    local ok = os.execute(cmd)
    if ok ~= 0 and ok ~= true then
        error("the request failed: " .. url)
    end
    local f = assert(io.open(out, "r"))
    local body = f:read("*a")
    f:close()
    os.remove(out)
    return body
end
-- }}}

-- {{{ local function json_string_at
-- Reads the JSON string starting at the quote at position i; returns the
-- decoded text and the position after it. (Only what this API reply needs.)
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
                    local low = tonumber(s:sub(j + 2, j + 5), 16)
                    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
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
-- }}}

-- {{{ local function pages_in
-- The pages in a reply: list of {title, missing (boolean), content}.
-- Redirects are followed by the API (redirects=1); their map is returned too.
local function pages_in(body)
    local pages, redirects = {}, {}
    local r = body:find('"redirects"', 1, true)
    if r then
        local stop = body:find("]", r, true)
        local chunk = body:sub(r, stop)
        for from_pos in chunk:gmatch('()"from":') do
            local from = json_string_at(chunk, chunk:find('"', from_pos + 7, true))
            local to_pos = chunk:find('"to":', from_pos, true)
            local to = json_string_at(chunk, chunk:find('"', to_pos + 5, true))
            redirects[from] = to
        end
    end
    local p = body:find('"pages"', 1, true)
    if not p then error("the reply has no pages") end
    local pos = p
    while true do
        local t = body:find('"title":', pos, true)
        if not t then break end
        local title, after = json_string_at(body, body:find('"', t + 8, true))
        local next_t = body:find('"title":', after, true) or #body
        local seg = body:sub(after, next_t)
        local page = { title = title, missing = seg:find('"missing":true', 1, true) ~= nil }
        local c = seg:find('"content":', 1, true)
        if c then
            page.content = json_string_at(seg, seg:find('"', c + 10, true))
        end
        pages[#pages + 1] = page
        pos = after
    end
    return pages, redirects
end
-- }}}

-- {{{ main
os.execute("mkdir -p " .. shell_quote(CACHE .. "/"))
local probe = io.open(CACHE .. "/.", "r")
if not probe then
    error("no " .. CACHE .. ": create it as a link to a folder beside the installs"
        .. " (see wc3-installs/README.md)")
end
probe:close()

if arg[1] == "--list" then
    for _, v in ipairs(VERSIONS) do
        local state = "not fetched"
        if io.open(cached_file(v), "r") then state = "cached" elseif io.open(CACHE .. "/" .. v .. ".missing", "r") then state = "no such page" end
        print(string.format("  %-8s %s", v, state))
    end
    os.exit(0)
end

local wanted, title_of = {}, {}
for _, v in ipairs(VERSIONS) do
    if not is_cached(v) then
        local title = "Patch " .. v
        wanted[#wanted + 1] = title
        title_of[title] = v
    end
end
-- {{{ subpages
-- Some pages keep sections on subpages and pull them in with {{/human}}
-- (Patch 1.22's balance changes). Those are fetched the same way, by the
-- title the main page was found under ("Patch 1.22/human"), and cached as
-- <version>.sub.<name>.wikitext.
local function page_title_of(version)
    local f = io.open(CACHE .. "/sources.tsv", "r")
    if not f then return nil end
    local title
    for line in f:lines() do
        local v, t = line:match("^([^\t]+)\t([^\t]+)\t")
        if v == version then title = t end
    end
    f:close()
    return title
end
local function sub_file(version, name)
    return CACHE .. "/" .. version .. ".sub." .. name:gsub("[^%w_ ]", "_") .. ".wikitext"
end
for _, v in ipairs(VERSIONS) do
    local f = io.open(cached_file(v), "r")
    if f then
        local text = f:read("*a")
        f:close()
        local title = page_title_of(v)
        for name in text:gmatch("{{/([^}|]+)}}") do
            local done = io.open(sub_file(v, name), "r") or io.open(sub_file(v, name) .. ".missing", "r")
            if done then done:close()
            elseif title then
                local sub_title = title .. "/" .. name:gsub("_", " ")
                if not title_of[sub_title] then
                    wanted[#wanted + 1] = sub_title
                    title_of[sub_title] = { version = v, sub = name }
                end
            end
        end
    end
end
-- }}}

if #wanted == 0 then
    print("every page is cached; nothing fetched")
    os.exit(0)
end

local log = assert(io.open(CACHE .. "/sources.tsv", "a"))
for first = 1, #wanted, 50 do
    local batch = {}
    for i = first, math.min(first + 49, #wanted) do batch[#batch + 1] = wanted[i] end
    print(string.format("one request for %d pages", #batch))
    local pages, redirects = pages_in(request(batch))
    local reverse = {}
    for from, to in pairs(redirects) do reverse[to] = from end
    local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
    for _, page in ipairs(pages) do
        local asked = reverse[page.title] or page.title
        local v = title_of[asked]
        if type(v) == "table" then
            local file = sub_file(v.version, v.sub)
            if page.missing or not page.content then
                local f = assert(io.open(file .. ".missing", "w")); f:write(now, "\n"); f:close()
                print(string.format("  %-8s /%s: no page", v.version, v.sub))
            else
                local f = assert(io.open(file, "w")); f:write(page.content); f:close()
                log:write(string.format("%s/%s\t%s\thttps://liquipedia.net/warcraft/%s\tCC BY-SA 3.0\t%s\n",
                    v.version, v.sub, page.title, page.title:gsub(" ", "_"), now))
                print(string.format("  %-8s /%s (%d bytes)", v.version, v.sub, #page.content))
            end
        elseif v then
            if page.missing or not page.content then
                local f = assert(io.open(CACHE .. "/" .. v .. ".missing", "w")); f:write(now, "\n"); f:close()
                print(string.format("  %-8s no page", v))
            else
                local f = assert(io.open(cached_file(v), "w")); f:write(page.content); f:close()
                log:write(string.format("%s\t%s\thttps://liquipedia.net/warcraft/%s\tCC BY-SA 3.0\t%s\n",
                    v, page.title, page.title:gsub(" ", "_"), now))
                print(string.format("  %-8s %s (%d bytes)", v, page.title, #page.content))
            end
        end
    end
end
log:close()
-- }}}
