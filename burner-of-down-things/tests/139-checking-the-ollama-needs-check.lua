-- 139-checking-the-ollama-needs-check.lua
--
-- Checks issue 903b: with ollama's server stopped, a turn using `ollama`
-- is refused by name — never quietly handed to another harness; with it
-- answering, the row is given. No real server is needed: a stand-in
-- `ollama` program on the PATH answers `ollama list` as a stopped or a
-- running server would.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs

local scratch = kit.scratch("ollama-needs")

-- {{{ local function fake_ollama
-- A folder holding a stand-in `ollama` whose `list` answers as given.
local function fake_ollama(label, list_script)
    local bin = scratch .. "/" .. label
    fs.make_folder(bin)
    kit.write_file(bin .. "/ollama", "#!/bin/sh\nif [ \"$1\" = list ]; then\n" .. list_script .. "\nfi\nexit 9\n")
    assert(fs.run("chmod +x " .. fs.quote(bin .. "/ollama")))
    return bin
end
-- }}}

-- {{{ local function row_with_path
-- Asks for the ollama row in a child luajit whose PATH starts with `bin`,
-- since a process cannot change its own PATH. Returns what it printed.
local function row_with_path(bin)
    local probe = scratch .. "/probe.lua"
    kit.write_file(probe, table.concat({
        "package.path = " .. string.format("%q", kit.DIR .. "/src/?.lua;") .. " .. package.path",
        "local h = require('037-the-harness-table')",
        "local ok, row = pcall(h.row, 'ollama')",
        "if ok then io.write('GIVEN ', row.name) else io.write('REFUSED ', tostring(row)) end",
    }, "\n"))
    local out = fs.capture("PATH=" .. fs.quote(bin) .. ":\"$PATH\" luajit " .. fs.quote(probe) .. " 2>&1")
    return out
end
-- }}}

local stopped = fake_ollama("stopped",
    "echo 'Error: could not connect to ollama app, is it running?' >&2\nexit 1")
local said = row_with_path(stopped)
kit.check(said:find("^REFUSED") ~= nil, "with the server stopped, the ollama row is refused: " .. said)
kit.check(said:find("'ollama'", 1, true) ~= nil, "the refusal names the harness")
kit.check(said:find("not serving", 1, true) ~= nil, "the refusal says the server is not answering")
kit.check(said:find("could not connect", 1, true) ~= nil, "the refusal quotes what `ollama list` said")
kit.check(said:find("ollama serve", 1, true) ~= nil, "the refusal says how to start the server")
kit.check(said:find("No other harness", 1, true) ~= nil, "the refusal says no other harness stands in")
kit.check(said:find("stand-in", 1, true) == nil and said:find("claude-code", 1, true) == nil,
    "no other harness is named or given in its place")

local running = fake_ollama("running",
    "printf 'NAME\\tID\\tSIZE\\tMODIFIED\\nllama3.2:1b\\tabc\\t1.3 GB\\t2 days ago\\n'\nexit 0")
kit.equal(row_with_path(running), "GIVEN ollama", "with the server answering, the ollama row is given")

local silent = fake_ollama("silent", "exit 1")
local quiet = row_with_path(silent)
kit.check(quiet:find("exit status 1", 1, true) ~= nil, "a server check that says nothing still refuses, giving the status: " .. quiet)

local harnesses = require("037-the-harness-table")
kit.equal(harnesses.TABLE["stand-in"].serving, nil, "the stand-in has no server to check")

kit.finish()
