#!/usr/bin/env luajit
-- share.lua - make, answer and check a shared map-and-model list (issue 609)
--
-- In plain terms: the steps of sharing your models for a map with a
-- playmate, as files, for whatever carries them (rmail, once its glue is
-- written; a USB stick until then). Nothing here touches the network.
--
-- Usage:
--   luajit src/cli/share.lua [--dir DIR] [--data FOLDER] make MAP PACK [--author NAME] [--type ID=PATH ...] [-o LIST]
--   luajit src/cli/share.lua [--dir DIR] [--data FOLDER] missing LIST          the hashes you lack, one a line
--   luajit src/cli/share.lua [--dir DIR] [--data FOLDER] bundle LIST PACK WANTED OUTDIR
--   luajit src/cli/share.lua [--dir DIR] [--data FOLDER] check LIST BUNDLE     would it apply? (nothing changes)
--   luajit src/cli/share.lua --help
--
-- MAP is the map file; PACK the name of one of your asset packs (or a
-- folder). make writes the list (to LIST, else to the screen) and names
-- the files it left out (only art and sound are shared). missing is the
-- receiver's answer; bundle copies the files WANTED names (a file of
-- hashes, as missing writes) into OUTDIR; check verifies a received
-- bundle against the list. Applying a list is done by the game, for one
-- game (share/profile.lua).
--
-- Issue: issues/completed/609-shared-map-and-model-list.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local DATA
while arg[1] == "--dir" or arg[1] == "--data" do
    if arg[1] == "--dir" then DIR = arg[2] else DATA = arg[2] end
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local list = require("share.list")
local profile = require("share.profile")
local dedup = require("assets.dedup")
local player_data = require("assets.player_data")

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end

local function load_list(path)
    local text = read_file(path)
    if not text then return nil, "no list at " .. path end
    return list.decode(text)
end

local function pack_dir(data, pack)
    if pack:find("/", 1, true) then return pack end
    return data .. "/asset-packs/" .. pack
end

local function main()
    if arg[1] == nil or arg[1] == "--help" or arg[1] == "-h" then
        for line in io.lines(arg[0]) do
            if not line:match("^%-%-") and line ~= "#!/usr/bin/env luajit" then break end
            if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
        end
        return 0
    end
    local data = DATA or player_data.folder(DIR)
    local cmd = table.remove(arg, 1)
    if cmd == "make" then
        local map, pack = arg[1], arg[2]
        if not map or not pack then io.stderr:write("usage: share.lua make MAP PACK [--author NAME] [--type ID=PATH] [-o LIST]\n"); return 2 end
        local opts = { map = map, pack = pack_dir(data, pack), types = {} }
        local out
        local i = 3
        while arg[i] do
            if arg[i] == "--author" then opts.author = arg[i + 1]; i = i + 2
            elseif arg[i] == "--type" then
                local id, path = (arg[i + 1] or ""):match("^(%w%w%w%w)=(.+)$")
                if not id then io.stderr:write("--type wants ID=PATH (hfoo=units/knight/knight.mdx)\n"); return 2 end
                opts.types[id] = path
                i = i + 2
            elseif arg[i] == "-o" then out = arg[i + 1]; i = i + 2
            else io.stderr:write("unknown option " .. arg[i] .. "\n"); return 2 end
        end
        local ok, l, left = pcall(list.build, opts)
        if not ok then io.stderr:write(tostring(l) .. "\n"); return 1 end
        local text = list.encode(l)
        if out then
            local f = assert(io.open(out, "wb")); f:write(text); f:close()
            print(string.format("Wrote %s: %d entries.", out, #l.entries))
        else
            io.write(text)
        end
        for _, rel in ipairs(left) do io.stderr:write("left out (not art or sound): " .. rel .. "\n") end
        return 0
    elseif cmd == "missing" then
        local l, err = load_list(arg[1] or "")
        if not l then io.stderr:write(err .. "\n"); return 1 end
        for _, h in ipairs(list.missing(l, dedup.open(data .. "/blobs"))) do print(h) end
        return 0
    elseif cmd == "bundle" then
        local l, err = load_list(arg[1] or "")
        if not l then io.stderr:write(err .. "\n"); return 1 end
        local wanted = {}
        for line in (read_file(arg[3] or "") or ""):gmatch("[^\n]+") do wanted[#wanted + 1] = line end
        local ok, n = pcall(list.bundle, l, pack_dir(data, arg[2] or ""), wanted, arg[4] or "")
        if not ok then io.stderr:write(tostring(n) .. "\n"); return 1 end
        print(string.format("Copied %d file%s into %s.", n, n == 1 and "" or "s", arg[4]))
        return 0
    elseif cmd == "check" then
        local l, err = load_list(arg[1] or "")
        if not l then io.stderr:write(err .. "\n"); return 1 end
        local problems = profile.verify(l, dedup.open(data .. "/blobs"), arg[2])
        if #problems == 0 then
            print(string.format("All %d entries are here and match their hashes.", #l.entries))
            return 0
        end
        for _, p in ipairs(problems) do print(p.key .. ": " .. p.problem) end
        print("Refused: nothing would be applied.")
        return 1
    end
    io.stderr:write("unknown command: " .. cmd .. " (try --help)\n")
    return 2
end

if arg and arg[0] and arg[0]:match("share%.lua$") then
    os.exit(main())
end
