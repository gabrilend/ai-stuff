#!/usr/bin/env luajit
-- fetch.lua - catalogue maps and models, and download the one the player picks
--
-- In plain terms: lists the public sites the project could fetch from and
-- whether each has been reviewed; makes a catalogue of the maps and models
-- in a folder on disk; lists a catalogue; and downloads one entry into the
-- player's storage, checked first (a map must open and parse, a model's
-- textures must decode) and stored once by its hash.
--
-- Usage:
--   luajit src/cli/fetch.lua [--dir DIR] [--data FOLDER] sources
--   luajit src/cli/fetch.lua [--dir DIR] [--data FOLDER] scan FOLDER [--as NAME]
--   luajit src/cli/fetch.lua [--dir DIR] [--data FOLDER] list SOURCE
--   luajit src/cli/fetch.lua [--dir DIR] [--data FOLDER] download SOURCE N [--network]
--
-- Local files only, unless asked: nothing is fetched over the network
-- without --network, and never from a site whose entry in
-- src/fetch/sources.lua isn't "allowed" (every site starts "unreviewed").
--
-- Issue: issues/603-fetch-maps-and-models-from-public-sites.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local DATA
while arg[1] == "--dir" or arg[1] == "--data" do
    if arg[1] == "--dir" then DIR = arg[2] else DATA = arg[2] end
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local fetch = require("fetch")
local storage = require("assets.storage")
local player_data = require("assets.player_data")

local function main()
    local args, network, as = {}, false, nil
    local i = 1
    while arg[i] do
        local a = arg[i]
        if a == "--network" then network = true
        elseif a == "--as" then as = arg[i + 1]; i = i + 1
        elseif a == "--help" or a == "-h" then
            for line in io.lines(arg[0]) do
                if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) elseif line ~= "#!/usr/bin/env luajit" then break end
            end
            return 0
        else args[#args + 1] = a end
        i = i + 1
    end
    local cmd = args[1]
    if cmd == "sources" then
        for _, s in ipairs(fetch.SOURCES) do
            local ok, why = fetch.may_fetch(s)
            print(string.format("%-18s %-14s %-32s %s", s.name, s.access, s.base, ok and "may be fetched with --network" or why))
        end
        return 0
    end
    local S = storage.open(DATA or player_data.folder(DIR))
    if cmd == "scan" and args[2] then
        local cat = fetch.scan_folder(args[2], as)
        local old = fetch.load(S, cat.source)
        -- keep what was downloaded before, by address
        if old then
            local had = {}
            for _, e in ipairs(old.entries) do had[e.download_url or ""] = e end
            for n, e in ipairs(cat.entries) do
                if had[e.download_url] and had[e.download_url].hash then cat.entries[n] = had[e.download_url] end
            end
        end
        fetch.save(S, cat)
        print(string.format("%s: %d entries, written to %s", cat.source, #cat.entries, fetch.catalogue_path(S, cat.source)))
        return 0
    elseif cmd == "list" and args[2] then
        local cat, err = fetch.load(S, args[2])
        if not cat then io.stderr:write(err .. "\n") return 1 end
        for n, e in ipairs(cat.entries) do
            print(string.format("%3d  %-5s  %-40s %s", n, e.kind, e.title, e.hash and ("downloaded " .. (e.downloaded or "")) or ""))
        end
        return 0
    elseif cmd == "download" and args[2] and tonumber(args[3]) then
        local cat, err = fetch.load(S, args[2])
        if not cat then io.stderr:write(err .. "\n") return 1 end
        local ok, res = pcall(fetch.download, S, cat, tonumber(args[3]), { network = network, root = DIR })
        if not ok then io.stderr:write(tostring(res) .. "\n") return 1 end
        fetch.save(S, cat)
        print(string.format("Downloaded %s: %s, stored as %s", res.title, res.hash, res.stored_as))
        if res.checked and res.checked.stock_unverified and #res.checked.stock_unverified > 0 then
            print("  stock textures not checked (no install here): " .. table.concat(res.checked.stock_unverified, ", "))
        end
        return 0
    end
    io.stderr:write("usage: fetch.lua sources | scan FOLDER [--as NAME] | list SOURCE | download SOURCE N [--network]\n")
    return 2
end

if arg and arg[0] and arg[0]:match("fetch%.lua$") then
    os.exit(main())
end
