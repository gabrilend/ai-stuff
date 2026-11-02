-- 143-checking-the-router-by-harness.lua
--
-- Checks issue 904's harness side: the router's answerer runs each
-- attempt as one ollama turn through the harness table (903), in its own
-- turn folder, and reads the answer 903d's wrapper wrote; with the server
-- stopped it refuses by name before any turn runs. A stand-in `ollama`
-- program on the PATH plays the server and the model, so nothing real is
-- started — the real run is by hand (904's step 2).

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs

local scratch = kit.scratch("router-harness")

-- {{{ local function fake_ollama
-- A stand-in ollama: `list` answers as `list_status` says; `run` reads the
-- prompt and answers with an invented station the first time it is run,
-- and the real one after, counting its runs in a file beside it.
local function fake_ollama(label, list_status)
    local bin = scratch .. "/" .. label
    fs.make_folder(bin)
    kit.write_file(bin .. "/ollama", table.concat({
        "#!/bin/sh",
        "if [ \"$1\" = list ]; then",
        "  [ " .. list_status .. " = 0 ] && echo 'NAME ID SIZE MODIFIED' && exit 0",
        "  echo 'Error: could not connect to ollama app, is it running?' >&2; exit 1",
        "fi",
        "[ \"$1\" = run ] || exit 9",
        "cat > /dev/null",
        "n=$(cat " .. fs.quote(bin .. "/runs") .. " 2>/dev/null || echo 0); n=$((n+1)); echo $n > " .. fs.quote(bin .. "/runs"),
        "if [ $n = 1 ]; then printf 'shape: table\\nstation: txt-tabel\\n'; else printf 'shape: table\\nstation: txt-table\\n'; fi",
    }, "\n") .. "\n")
    assert(fs.run("chmod +x " .. fs.quote(bin .. "/ollama")))
    return bin
end
-- }}}

-- {{{ local function route_with_path
-- Routes a table parcel in a child luajit whose PATH starts with `bin`.
local function route_with_path(bin, label)
    local work = scratch .. "/" .. label
    fs.make_folder(work .. "/parcel")
    kit.write_file(work .. "/parcel/t.lua", "return { { 'a', 'b' } }\n")
    local probe = work .. "/probe.lua"
    kit.write_file(probe, table.concat({
        "local DIR = " .. string.format("%q", kit.DIR),
        "package.path = DIR .. '/src/?.lua;' .. package.path",
        "local router = require('141-the-router')",
        "local parcel = require('079-the-parcel')",
        "local stations = require('093-the-station-table')",
        "local ok, result = pcall(function()",
        "  local ask = router.harness_asker({ src = DIR .. '/src', dir = DIR }, " .. string.format("%q", work .. "/turns") .. ", 'tiny:1b')",
        "  return router.route({ rows = stations.TABLE, parcel = parcel.read(" .. string.format("%q", work .. "/parcel") .. "), ask = ask })",
        "end)",
        "if not ok then io.write('REFUSED ', tostring(result)) else",
        "  io.write(result.status, ' ', tostring(result.station), ' ', result.attempts) end",
    }, "\n"))
    return fs.capture("PATH=" .. fs.quote(bin) .. ":\"$PATH\" luajit " .. fs.quote(probe) .. " 2>&1"), work
end
-- }}}

local said, work = route_with_path(fake_ollama("serving", 0), "serving")
kit.equal(said, "routed txt-table 2", "an ollama router's invented station is sent back, and its second answer routed")
kit.check(fs.exists(work .. "/turns/route-1/result.json") and fs.exists(work .. "/turns/route-2/result.json"),
    "each attempt is its own turn folder with its own result.json")
kit.check(fs.read(work .. "/turns/route-2/prompt.md"):find("there is no station 'txt-tabel'; the nearest are 'txt-table'", 1, true) ~= nil,
    "the second turn's prompt says why the first answer was sent back")
kit.equal(fs.read(work .. "/turns/route-1/exit"), "0\n", "each turn's exit is recorded by the harness table's shell line")

local refused, stopped_work = route_with_path(fake_ollama("stopped", 1), "stopped")
kit.check(refused:find("^REFUSED") ~= nil and refused:find("'ollama' is installed but not serving", 1, true) ~= nil,
    "with the server stopped, the router refuses by name: " .. refused)
kit.check(not fs.exists(stopped_work .. "/turns"), "and no turn is run before the refusal")

kit.finish()
