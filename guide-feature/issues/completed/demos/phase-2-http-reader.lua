-- phase-2-http-reader.lua - the phase 2 demo's second reader: the HTTP
-- canvas server (204), as a remote viewer would use it.
--
-- It asks GET /canvas once, then holds GET /canvas?after=N, one request at
-- a time, each answered when a newer version exists (or 204 after the
-- server's wait, and it asks again). When the answer skips versions (two
-- made between its requests), it fetches each one missed with GET
-- /canvas/N. Every version is read through the viewer-side reader (202),
-- saved byte for byte as OUT/NNNNNN, and a line goes to OUT/received:
--   <version> <first|wait|history> <seconds since 1970, to the microsecond>
-- It stops when OUT/stop appears, even mid-wait, writing OUT/done.
--
-- usage (phase-2-demo starts it):
--   luajit phase-2-http-reader.lua --root PROJECT --out FOLDER --port N

-- {{{ arguments
local ROOT, OUT, PORT
for index = 1, #arg do
    if arg[index] == "--root" then ROOT = arg[index + 1] end
    if arg[index] == "--out" then OUT = arg[index + 1] end
    if arg[index] == "--port" then PORT = tonumber(arg[index + 1]) end
end
if not (ROOT and OUT and PORT) then
    io.stderr:write("usage: luajit phase-2-http-reader.lua --root PROJECT --out FOLDER "
        .. "--port N\n")
    os.exit(2)
end
-- }}}

local socket = require("socket")
local viewer = dofile(ROOT .. "/src/022-viewer.lua")

-- {{{ small helpers
local function exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() end
    return handle ~= nil
end
local function stopping() return exists(OUT .. "/stop") end
local received = assert(io.open(OUT .. "/received", "a"))
received:setvbuf("line")
local counts = { requests = 0, ["answered-200"] = 0, ["answered-204"] = 0, other = 0 }
-- }}}

-- {{{ local function get()
-- One request on 127.0.0.1; returns the status and the body, or nil when
-- the reader is told to stop while it waits.
local function get(path)
    local client = assert(socket.connect("127.0.0.1", PORT))
    counts.requests = counts.requests + 1
    assert(client:send("GET " .. path .. " HTTP/1.1\r\nHost: 127.0.0.1\r\n"
        .. "Connection: close\r\n\r\n"))
    client:settimeout(0.1)
    local parts = {}
    while true do
        local data, problem, partial = client:receive("*a")
        if data then parts[#parts + 1] = data break end
        if partial and #partial > 0 then parts[#parts + 1] = partial end
        if problem == "closed" then break end
        if stopping() then client:close() return nil end
    end
    client:close()
    local answer = table.concat(parts)
    local status = tonumber(string.match(answer, "^HTTP/1%.1 (%d%d%d)"))
    local body = string.match(answer, "\r\n\r\n(.*)$") or ""
    if status == 200 then
        counts["answered-200"] = counts["answered-200"] + 1
    elseif status == 204 then
        counts["answered-204"] = counts["answered-204"] + 1
    else
        counts.other = counts.other + 1
    end
    return status, body
end
-- }}}

-- {{{ local function keep()
local function keep(text, how)
    local view, problem = viewer.read(text, "an HTTP answer")
    if not view then
        received:write("unreadable " .. how .. " " .. tostring(problem) .. "\n")
        return nil
    end
    local name = string.format("%s/%06d", OUT, view.version)
    local handle = assert(io.open(name .. ".part", "wb"))
    handle:write(text)
    handle:close()
    assert(os.rename(name .. ".part", name))
    received:write(string.format("%d %s %.6f\n", view.version, how, socket.gettime()))
    return view.version
end
-- }}}

-- {{{ reading
local last
while not stopping() and not last do
    local status, body = get("/canvas")
    if status == 200 then last = keep(body, "first") end
    if not last then socket.sleep(0.05) end
end
while last and not stopping() do
    local status, body = get("/canvas?after=" .. last)
    if status == 200 then
        local got = keep(body, "wait")
        if got then
            for missed = last + 1, got - 1 do
                local old_status, old = get("/canvas/" .. missed)
                if old_status == 200 then keep(old, "history") end
            end
            last = math.max(last, got)
        end
    end
end
received:close()
local done = assert(io.open(OUT .. "/done", "w"))
done:write("stopped at version " .. tostring(last) .. "\n")
for _, name in ipairs({ "requests", "answered-200", "answered-204", "other" }) do
    done:write(string.format("%s %d\n", name, counts[name]))
end
done:close()
-- }}}
