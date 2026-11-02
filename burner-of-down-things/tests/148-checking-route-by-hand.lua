-- 148-checking-route-by-hand.lua
--
-- Checks issue 904's by-hand script (step 2's tool), with a stand-in
-- `ollama` on the PATH so no real model runs: it prints each prompt and
-- answer and the outcome, keeps the turn folders and names them, writes
-- no ledger, and refuses when no model is named anywhere.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs

local scratch = kit.scratch("route-by-hand")
local bin = scratch .. "/bin"
fs.make_folder(bin)
kit.write_file(bin .. "/ollama", table.concat({
    "#!/bin/sh",
    "[ \"$1\" = list ] && echo NAME && exit 0",
    "[ \"$1\" = run ] || exit 9",
    "cat > /dev/null",
    "printf 'shape: table\\nstation: txt-table\\n'",
}, "\n") .. "\n")
assert(fs.run("chmod +x " .. fs.quote(bin .. "/ollama")))

-- A project copy whose scratch space is inside this check's own folder.
local project_dir = scratch .. "/project"
assert(fs.run("mkdir -p " .. fs.quote(project_dir) .. " && cp -r " .. fs.quote(kit.DIR .. "/src") .. " " .. fs.quote(project_dir .. "/src")))
fs.make_folder(project_dir .. "/tmp/shared-memory")
fs.make_folder(scratch .. "/parcel")
kit.write_file(scratch .. "/parcel/t.lua", "return { { 'a', 'b' } }\n")

local script = kit.DIR .. "/scripts/147-route-by-hand.lua"
local run = "PATH=" .. fs.quote(bin) .. ":\"$PATH\" luajit " .. fs.quote(script) .. " " .. fs.quote(project_dir)
    .. " " .. fs.quote(scratch .. "/parcel")

local out, ok = fs.capture(run .. " tiny:1b 2>&1")
kit.check(ok, "with a model named, the script routes and exits 0: " .. out)
kit.check(out:find("---- attempt 1: the prompt ----", 1, true) ~= nil, "it prints the prompt")
kit.check(out:find("station: txt-table", 1, true) ~= nil, "it prints the model's answer")
kit.check(out:find("routed: shape table, station txt-table, after 1 attempt(s)", 1, true) ~= nil, "it prints the outcome")
local turns = out:match("turn folders: ([^\n]+)")
kit.check(turns and fs.exists(turns .. "/route-1/result.json"), "it keeps the turn folders and names them")
kit.check(turns and turns:sub(1, #project_dir) == project_dir, "under the project's own scratch space")

local refused, refused_ok = fs.capture(run .. " 2>&1")
kit.check(not refused_ok and refused:find("no model named", 1, true) ~= nil,
    "with no model named and none in the settings, it refuses rather than guess: " .. refused)

kit.finish()
