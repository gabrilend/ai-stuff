#!/usr/bin/env luajit
-- storage.lua - what the player's maps and asset packs take up, and clearing them out
--
-- In plain terms: every map and asset pack the player keeps is a folder of
-- links into one store where each file is kept once (issue 604). This tool
-- shows how much each takes, how much of that is its own (what deleting it
-- frees) and what it shares; deletes a map or pack, after asking; and
-- removes stored files nothing uses any more.
--
-- Usage:
--   luajit src/cli/storage.lua [--dir DIR] [--data FOLDER] [--detail]   the overview
--   luajit src/cli/storage.lua [--dir DIR] [--data FOLDER] report         the overview in full
--   luajit src/cli/storage.lua [--dir DIR] [--data FOLDER] delete map|pack NAME [--force]
--   luajit src/cli/storage.lua [--dir DIR] [--data FOLDER] gc
--   luajit src/cli/storage.lua [--dir DIR] [--data FOLDER] orphans
--   luajit src/cli/storage.lua --help
--
-- DIR is the project (its player data folder is player-data/, unless
-- config/player-data.lua moves it); --data names a player data folder
-- directly. delete asks first, and with no answer (not a terminal, say)
-- deletes nothing; --force skips the question. delete then collects, so
-- the space is freed at once.
--
-- Issue: issues/completed/605-local-storage-manager.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local DATA
while arg[1] == "--dir" or arg[1] == "--data" do
    if arg[1] == "--dir" then DIR = arg[2] else DATA = arg[2] end
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local storage = require("assets.storage")
local player_data = require("assets.player_data")

local M = {}

local size = storage.size

local function count(n, one, many)
    return n .. " " .. (n == 1 and one or many)
end

-- {{{ local function width / pad
local function width(s)
    local _, cont = s:gsub("[\128-\191]", "")
    return #s - cont
end

local function pad(s, n)
    return s .. string.rep(" ", math.max(n - width(s), 0))
end

local function lpad(s, n)
    return string.rep(" ", math.max(n - width(s), 0)) .. s
end
-- }}}

-- {{{ M.render
-- The overview as text; DETAIL adds each source's files, shared bytes and
-- broken links.
function M.render(S, detail)
    local o = S:overview()
    local out = {}
    local function add(line) out[#out + 1] = line end
    local name_w = 30
    for _, list in ipairs({ o.maps, o.packs }) do
        for _, info in ipairs(list) do name_w = math.max(name_w, width(info.name) + 2) end
    end
    local full = name_w + 2 + 10 + 10 + 12
    add("Player data: " .. S.folder)
    add(string.rep("═", full))
    add(string.format("Total: %s (would be %s without keeping each file once)", size(o.total_bytes), size(o.naive_bytes)))
    add(string.format("Savings: %s (%d%%)", size(o.savings_bytes), o.savings_percent))
    local function section(title, list)
        add("")
        add(pad(title, name_w + 2) .. lpad("SIZE", 10) .. lpad("UNIQUE", 10) .. lpad("LAST USED", 12))
        add(string.rep("─", full))
        if #list == 0 then add("  (none)") end
        for _, info in ipairs(list) do
            local when = info.last_used and os.date("%Y-%m-%d", info.last_used) or "—"
            add("  " .. pad(info.name, name_w) .. lpad(size(info.total_bytes), 10)
                .. lpad(size(info.unique_bytes), 10) .. lpad(when, 12))
            if detail then
                add(string.format("      %s (%d different), %s shared%s", count(info.file_count, "file", "files"),
                    info.blob_count, size(info.shared_bytes), info.broken_links > 0
                        and (", " .. count(info.broken_links, "broken link", "broken links")) or ""))
            end
        end
    end
    section("ASSET PACKS", o.packs)
    section("MAPS", o.maps)
    add("")
    add(pad("SHARED", name_w + 2) .. lpad(size(o.shared_bytes), 10) .. "   (used by more than one map or pack)")
    add(pad("UNUSED", name_w + 2) .. lpad(size(o.orphan_bytes), 10)
        .. string.format("   (%s nothing uses; gc removes them)", count(o.orphan_count, "stored file", "stored files")))
    if detail then
        add("")
        add(string.format("%s, each stored once: %s in all.", count(o.blob_count, "different file", "different files"),
            size(o.total_bytes)))
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ M.delete
-- Deletes KIND NAME after asking ASK(question) (true to go on), unless
-- FORCE; then collects. Returns the message to print, and true when done.
function M.delete(S, kind, name, force, ask)
    local info = S:info(kind, name)
    if not info then
        return "No " .. (kind == "pack" and "asset pack" or "map") .. " named " .. name .. ".", false
    end
    if not force then
        local q = string.format("Delete the %s %s? This frees about %s%s. [y/N] ",
            kind == "pack" and "asset pack" or "map", name, size(info.unique_bytes),
            info.shared_bytes > 0 and (" (" .. size(info.shared_bytes) .. " more is shared, and stays)") or "")
        if not ask(q) then return "Nothing deleted.", false end
    end
    S:delete(kind, name)
    local removed, freed = S:gc()
    return string.format("Deleted %s. Removed %s nothing uses any more, freed %s.",
        name, count(removed, "stored file", "stored files"), size(freed + info.plain_bytes)), true
end
-- }}}

-- {{{ local function ask_terminal
local function ask_terminal(question)
    io.write(question)
    io.flush()
    local answer = io.read("*l")
    return answer ~= nil and (answer:lower() == "y" or answer:lower() == "yes")
end
-- }}}

-- {{{ function main
local function main()
    local args, force, detail = {}, false, false
    for _, a in ipairs(arg) do
        if a == "--force" then force = true
        elseif a == "--detail" then detail = true
        elseif a == "--help" or a == "-h" then
            for line in io.lines(arg[0]) do
                if not line:match("^%-%-") and line ~= "#!/usr/bin/env luajit" then break end
                if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
            end
            return 0
        else args[#args + 1] = a end
    end
    local S = storage.open(DATA or player_data.folder(DIR))
    local cmd = args[1] or "overview"
    if cmd == "overview" then
        io.write(M.render(S, detail))
    elseif cmd == "report" then
        io.write(M.render(S, true))
    elseif cmd == "delete" then
        local kind, name = args[2], args[3]
        if not storage.KINDS[kind] or not name then
            io.stderr:write("usage: storage.lua delete map|pack NAME [--force]\n")
            return 2
        end
        local msg, done = M.delete(S, kind, name, force, ask_terminal)
        print(msg)
        return done and 0 or 1
    elseif cmd == "gc" then
        local removed, freed = S:gc()
        print(string.format("Removed %s nothing used, freed %s.", count(removed, "stored file", "stored files"), size(freed)))
    elseif cmd == "orphans" then
        for _, hash in ipairs(S:orphans()) do print(hash) end
    else
        io.stderr:write("unknown command: " .. cmd .. " (try --help)\n")
        return 2
    end
    return 0
end
-- }}}

if arg and arg[0] and arg[0]:match("storage%.lua$") then
    os.exit(main())
end
return M
