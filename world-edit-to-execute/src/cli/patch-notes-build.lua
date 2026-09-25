#!/usr/bin/env luajit
-- patch-notes-build.lua - turn the cached Liquipedia patch notes into the page's notes file
--
-- In plain terms: patch-notes-fetch.lua keeps Liquipedia's pages for the
-- versions the project doesn't read. This tool turns each into plain
-- sections and bullet lines (wiki markup, links and icons stripped;
-- subpages spliced in where the page includes them) and writes notes.js for
-- the balance history page, which shows them as text, marked as not
-- supported. Nothing is fetched here.
--
-- The text is Liquipedia's (CC BY-SA 3.0): notes.js carries each version's
-- source page and licence, and stays beside the page on this machine.
--
-- Usage:
--   luajit src/cli/patch-notes-build.lua [--dir DIR] <output folder>
--
-- Issue: issues/completed/115b-notes-for-versions-we-dont-read.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
local CACHE = DIR .. "/wc3-installs/external-notes"

local M = {}

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
-- }}}

-- {{{ function M.plain
-- One line of wiki markup as plain text: icons and files dropped, links to
-- their shown text, bold/italic and code marks removed, entities decoded,
-- leftover templates and tags removed.
function M.plain(line)
    local s = line
    s = s:gsub("%[%[[Ff]ile:[^%]]*%]%]", "")
    s = s:gsub("%[%[[^%]|]*|([^%]]*)%]%]", "%1")
    s = s:gsub("%[%[([^%]]*)%]%]", "%1")
    s = s:gsub("%[https?://%S+%s+([^%]]*)%]", "%1")
    s = s:gsub("'''''", ""):gsub("'''", ""):gsub("''", "")
    s = s:gsub("<ref[^>]*/>", ""):gsub("<ref.-</ref>", "")
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("{{[^{}]*}}", "")
    s = s:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end
-- }}}

-- {{{ local function splice
-- Replaces {{/name}} with the cached subpage's text (one level; a subpage
-- that couldn't be fetched leaves a note saying so).
-- Subpages list each change as a structured template spread over several
-- lines ({{Patch object | ... |text=[[Knight]] damage increased ... }}); each
-- becomes one bullet of its text=, and the page's <noinclude> header goes.
local function flatten_patch_objects(sub)
    sub = sub:gsub("<noinclude>.-</noinclude>", "")
    sub = sub:gsub("{{Patch object(.-)\n}}", function(body)
        local t = body:match("|text=([^\n]*)") or ""
        return t
    end)
    return sub
end
local function splice(text, version)
    return (text:gsub("{{/([^}|]+)}}", function(name)
        local sub = read_file(CACHE .. "/" .. version .. ".sub." .. name:gsub("[^%w_ ]", "_") .. ".wikitext")
        if not sub then
            return "* (this section is on a subpage that wasn't fetched: " .. name .. ")"
        end
        return flatten_patch_objects(sub)
    end))
end
-- }}}

-- {{{ function M.parse
-- A page's text as { release, version, sections = { {heading, level, lines = { {text, depth} }} } }.
function M.parse(text, version)
    text = splice(text, version)
    local info = {}
    local box = text:match("{{[Ii]nfobox patch(.-)\n}}")
    if box then
        info.release = box:match("|release=([^\n|]*)")
        info.build = box:match("|version=([^\n|]*)")
        if info.build == "" then info.build = nil end
    end
    text = text:gsub("{{[Ii]nfobox patch.-\n}}", "")
    local sections = { { heading = "", level = 2, lines = {} } }
    for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
        local eq, title = raw:match("^(==+)%s*(.-)%s*==+%s*$")
        if eq then
            sections[#sections + 1] = { heading = M.plain(title), level = #eq, lines = {} }
        else
            local stars, rest = raw:match("^(%*+)%s*(.*)$")
            local line = M.plain(rest or raw)
            if line ~= "" and not raw:match("^{{") and not raw:match("^__") then
                local cur = sections[#sections].lines
                cur[#cur + 1] = { text = line, depth = stars and #stars or 0 }
            end
        end
    end
    local kept = {}
    for _, sec in ipairs(sections) do
        if #sec.lines > 0 then kept[#kept + 1] = sec end
    end
    info.sections = kept
    return info
end
-- }}}

-- {{{ local function quote
local function quote(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
-- }}}

-- {{{ function M.build
-- Every cached version's notes: version -> {title, url, license, fetched, release, build, sections}.
function M.build()
    local out = {}
    local f = io.open(CACHE .. "/sources.tsv", "r")
    if not f then return out end
    for line in f:lines() do
        local version, title, url, license, fetched = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)")
        if version and not version:find("/", 1, true) then
            local text = read_file(CACHE .. "/" .. version .. ".wikitext")
            if text then
                local info = M.parse(text, version)
                info.title, info.url, info.license, info.fetched = title, url, license, fetched
                out[version] = info
            end
        end
    end
    f:close()
    return out
end
-- }}}

-- {{{ function M.write
function M.write(notes, folder)
    local parts = {}
    local versions = {}
    for v in pairs(notes) do versions[#versions + 1] = v end
    table.sort(versions)
    for _, v in ipairs(versions) do
        local n = notes[v]
        local secs = {}
        for _, sec in ipairs(n.sections) do
            local lines = {}
            for _, l in ipairs(sec.lines) do lines[#lines + 1] = "[" .. l.depth .. "," .. quote(l.text) .. "]" end
            secs[#secs + 1] = "{\"heading\":" .. quote(sec.heading) .. ",\"level\":" .. sec.level .. ",\"lines\":[" .. table.concat(lines, ",") .. "]}"
        end
        parts[#parts + 1] = quote(v) .. ":{\"title\":" .. quote(n.title) .. ",\"url\":" .. quote(n.url)
            .. ",\"license\":" .. quote(n.license) .. ",\"fetched\":" .. quote(n.fetched)
            .. ",\"release\":" .. quote(n.release or "") .. ",\"build\":" .. quote(n.build or "")
            .. ",\"sections\":[" .. table.concat(secs, ",") .. "]}"
    end
    os.execute("mkdir -p '" .. folder .. "'")
    local f = assert(io.open(folder .. "/notes.js", "w"))
    f:write("// Patch notes from Liquipedia's Warcraft III wiki (https://liquipedia.net/warcraft/), CC BY-SA 3.0.\n")
    f:write("// For versions this project does not read; shown as text only. Made on this machine; not for redistribution with the project.\n")
    f:write("window.NOTES = {" .. table.concat(parts, ",") .. "};\n")
    f:close()
end
-- }}}

-- {{{ main
if arg and arg[0] and arg[0]:match("patch%-notes%-build%.lua$") then
    local folder = arg[1]
    if not folder or folder == "--help" then
        print("Usage: luajit src/cli/patch-notes-build.lua [--dir DIR] <output folder>")
        os.exit(folder and 0 or 1)
    end
    local notes = M.build()
    M.write(notes, folder)
    local n = 0
    for _ in pairs(notes) do n = n + 1 end
    print(string.format("patch notes for %d versions written to %s/notes.js", n, folder))
end
-- }}}

return M
