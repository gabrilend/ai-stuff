#!/usr/bin/env luajit
-- 025-canvas-server.lua - the HTTP canvas server: the one door from outside.
--
-- In plain terms: screens away from kuvalu (a browser, a phone, a watch) get
-- the canvas over HTTP. This small server answers the requests in
-- docs/canvas-protocol.md with the canvas files the blitter writes (203):
--
--   GET /canvas            the newest version
--   GET /canvas?after=N    waits up to wait-seconds for a version above N,
--                          then answers with it, or 204 if none came
--   GET /canvas/N          version N from history, or 404
--   GET /                  the HTML page (803, src/077-html-page.html)
--   GET /session?viewer=NAME
--                          a fresh session key, locked with that viewer's
--                          own key (src/076-html-page.lua)
--
-- Each canvas route takes `session=ID` too (`/canvas?after=N&session=ID`),
-- and then sends the canvas locked with that session's key, as hex. Without
-- one, the canvas goes as plain text only where `send-plain` allows: to the
-- four machines (`local`), to `everyone`, or to `nobody`
-- (docs/network.md).
--
-- Anything else is 404, and a method other than GET is 405. It is the
-- "narrow cause-way" the router forwards one port to (docs/network.md), so
-- it is built narrow: read-only, its own program, reading only
-- tmp/shared-memory/canvas/, with limits on open connections, request size
-- and how long a request may take to arrive, and one log line for every
-- request from outside the four machines.
--
-- Waiting requests are coroutines on one LuaSocket loop. It learns of a new
-- version by reading the first line of canvas/current a few times a second,
-- so the blitter and the server can each be restarted alone.
--
--   luajit src/025-canvas-server.lua [--dir ROOT]    run until a clean stop
--   scripts/run-canvas-server [ROOT]                 the same, with Ctrl-C or
--                                                    TERM as a clean stop
--
-- A clean stop is a file tmp/shared-memory/canvas-server.stop: the server
-- closes every connection, writes its goodbye receipt and exits.
--
-- As a library (tests): local s = server.new({ root = ROOT }); s:tick(0.1);
-- s.port; s:finish(). LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local socket = require("socket")
local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local page    -- src/076-html-page.lua, loaded by M.new

local M = {}

-- {{{ M.SETTINGS
-- input/canvas-server, read once at start.
M.SETTINGS = {
    ["listen-address"]    = { type = "text", required = true },
    ["port"]              = { type = "whole", required = true },
    ["max-connections"]   = { type = "whole", required = true },
    ["max-request-bytes"] = { type = "whole", required = true },
    ["request-seconds"]   = { type = "decimal", required = true },
    ["wait-seconds"]      = { type = "decimal", required = true },
    ["check-seconds"]     = { type = "decimal", required = true },
    ["local-addresses"]   = { type = "names", required = true },
    ["send-plain"]        = { type = "choice", of = { "local", "everyone", "nobody" }, required = true },
    ["viewers-file"]      = { type = "text", required = true },
    ["session-seconds"]   = { type = "decimal", required = true },
    ["max-sessions"]      = { type = "whole", required = true },
    ["password-rounds"]   = { type = "whole", required = true },
}
-- }}}

-- {{{ M.STATUS
M.STATUS = {
    [200] = "OK", [204] = "No Content", [403] = "Forbidden", [404] = "Not Found",
    [405] = "Method Not Allowed", [408] = "Request Timeout", [413] = "Content Too Large",
    [500] = "Internal Server Error", [503] = "Service Unavailable",
}
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ local function respond()
-- One whole answer, then the connection is closed: no keep-alive, so no
-- connection outlives its one request.
local function respond(client, status, body, extra, content_type)
    body = status == 204 and "" or (body or "")
    local head = { "HTTP/1.1 " .. status .. " " .. M.STATUS[status],
                   "Content-Length: " .. #body, "Connection: close", "Cache-Control: no-store" }
    if status ~= 204 then
        head[#head + 1] = "Content-Type: " .. (content_type or "text/plain; charset=utf-8")
    end
    for _, line in ipairs(extra or {}) do head[#head + 1] = line end
    client.sock:settimeout(2)
    client.sock:send(table.concat(head, "\r\n") .. "\r\n\r\n" .. body)
    return status
end
-- }}}

-- {{{ local function query_fields()
-- The query as name -> value, and how many: only `after`, `session` and
-- `viewer`, each value a whole number, hex or a name. Anything else is not a
-- route (nil). Each route asks for exactly as many as it takes, so a name
-- given twice never matches one.
local QUERY = { after = "^%d+$", session = "^%x+$", viewer = "^[%w%._%-]+$" }
local function query_fields(query)
    if query == nil then return {}, 0 end
    local fields, count = {}, 0
    for part in string.gmatch(query .. "&", "([^&]*)&") do
        local name, value = string.match(part, "^([a-z]+)=(.+)$")
        if not name or not QUERY[name] or not string.match(value, QUERY[name]) then
            return nil
        end
        fields[name], count = value, count + 1
    end
    return fields, count
end

-- A whole number as the protocol writes it: no leading zeros.
local function whole(text)
    if not text or (#text > 1 and string.sub(text, 1, 1) == "0") then return nil end
    return tonumber(text)
end
-- }}}

-- {{{ M.ROUTES
-- A table from route name to { match, handler }. `match` takes the path and
-- the query's fields (and how many) and returns the route's argument, or
-- nil. A handler takes the server and the client, and the argument, and
-- answers. It may wait for a new version by yielding. The canvas routes
-- first find how the canvas is to be sent (Server:lock_for).
M.ROUTES = {
    {
        name = "canvas",
        match = function(path, fields, count)
            return path == "/canvas" and count == (fields.session and 1 or 0)
                and { session = fields.session } or nil
        end,
        handle = function(self, client, argument)
            local lock, refusal = self:lock_for(client, argument.session)
            if not lock then return respond(client, 403, refusal) end
            local text = self:current_text()
            if not text then return respond(client, 404, "no canvas yet\n") end
            return respond(client, 200, lock(text))
        end,
    },
    {
        name = "canvas-after",
        match = function(path, fields, count)
            local after = whole(fields.after)
            return path == "/canvas" and after and count == (fields.session and 2 or 1)
                and { after = after, session = fields.session } or nil
        end,
        handle = function(self, client, argument)
            local lock, refusal = self:lock_for(client, argument.session)
            if not lock then return respond(client, 403, refusal) end
            local deadline = socket.gettime() + self.settings["wait-seconds"]
            while not (self.version and self.version > argument.after) do
                local event = coroutine.yield("wait", deadline)
                if event == "late" then
                    self.run:count("waits-timed-out")
                    return respond(client, 204)
                end
                if event == "gone" then
                    self.run:count("waits-abandoned")
                    return nil
                end
            end
            self.run:count("waits-answered")
            return respond(client, 200, lock(self:current_text()))
        end,
    },
    {
        name = "canvas-version",
        match = function(path, fields, count)
            local number = whole(string.match(path, "^/canvas/(%d+)$"))
            return number and count == (fields.session and 1 or 0)
                and { number = number, session = fields.session } or nil
        end,
        handle = function(self, client, argument)
            local lock, refusal = self:lock_for(client, argument.session)
            if not lock then return respond(client, 403, refusal) end
            local text = read_file(string.format("%s/history/%06d", self.canvas_folder,
                argument.number))
            if not text then return respond(client, 404, "no version " .. argument.number .. "\n") end
            return respond(client, 200, lock(text))
        end,
    },
    {
        name = "page",
        match = function(path, fields, count) return path == "/" and count == 0 or nil end,
        handle = function(self, client)
            return respond(client, 200, self.page_html, {
                -- the page's own script and style only, and requests to this server only
                "Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; "
                    .. "style-src 'unsafe-inline'; connect-src 'self'; form-action 'none'; "
                    .. "base-uri 'none'; frame-ancestors 'none'",
                "Referrer-Policy: no-referrer", "X-Content-Type-Options: nosniff",
            }, "text/html; charset=utf-8")
        end,
    },
    {
        name = "session",
        match = function(path, fields, count)
            return path == "/session" and fields.viewer and count == 1 and fields.viewer or nil
        end,
        handle = function(self, client, name)
            local viewers, problem = page.read_viewers(self.viewers_path)
            if not viewers then
                self.run:log("the viewers file cannot be read: " .. problem)
                return respond(client, 500, "the server's viewers file is wrong; see its log\n")
            end
            local viewer = viewers[name]
            if not viewer then
                self.run:count("refused-no-viewer")
                return respond(client, 404, "no viewer by that name\n")
            end
            local _, answer = self.sessions:start(name, viewer)
            self.run:count("sessions-started")
            return respond(client, 200, answer)
        end,
    },
}
-- }}}

-- {{{ local Server
local Server = {}
Server.__index = Server

-- {{{ function Server:refresh()
-- The newest version's number, from the first line of current; the whole
-- text is read only when it is sent.
function Server:refresh()
    local handle = io.open(self.canvas_folder .. "/current", "r")
    local first = handle and handle:read("*l")
    if handle then handle:close() end
    local version = tonumber(string.match(first or "", "^canvas: (%d+)$"))
    local changed = version ~= self.version
    self.version = version
    return changed
end

function Server:current_text()
    return read_file(self.canvas_folder .. "/current")
end
-- }}}

-- {{{ function Server:lock_for()
-- How this client is sent the canvas: a function from the canvas text to
-- the body, or nil and the refusal. In a session, locked with its key; with
-- no session, as plain text where send-plain allows it.
function Server:lock_for(client, id)
    if id then
        local session = self.sessions:find(id)
        if not session then
            self.run:count("refused-no-session")
            return nil, "no such session (it may have ended); start one at /session\n"
        end
        return function(text) return page.lock_canvas(session, id, text) end
    end
    local plain = self.settings["send-plain"]
    if plain == "everyone" or (plain == "local" and self.locals[client.address]) then
        return function(text) return text end
    end
    self.run:count("refused-plain")
    return nil, "the canvas is sent here only locked, in a session: open the page at /\n"
end
-- }}}

-- {{{ function Server:log_request()
-- One line for a request from outside the four machines: address, request
-- line (or - when none arrived), answer.
function Server:log_request(client, status)
    if not self.locals[client.address] then
        self.run:log(string.format("%s %s %s", client.address, client.request or "-",
            status and tostring(status) or "closed"))
    end
end
-- }}}

-- {{{ local function serve()
-- The life of one connection, as a coroutine: read the request head (yielding
-- until more arrives), then route it.
local function serve(self, client)
    local head = ""
    while not string.find(head, "\r\n\r\n", 1, true) do
        local event = coroutine.yield("read", client.deadline)
        if event == "late" then
            self.run:count("refused-too-slow")
            return respond(client, 408, "the request took too long to arrive\n")
        end
        local data, problem, partial = client.sock:receive(4096)
        data = data or partial or ""
        head = head .. data
        if #head > self.settings["max-request-bytes"] then
            self.run:count("refused-too-large")
            return respond(client, 413, "the request is too large\n")
        end
        if problem == "closed" and not string.find(head, "\r\n\r\n", 1, true) then
            return nil
        end
    end
    local line = string.match(head, "^([^\r\n]*)")
    client.request = line
    local method, target = string.match(line, "^(%u+) (%S+) HTTP/1%.[01]$")
    if not method then
        self.run:count("refused-not-found")
        return respond(client, 404, "not a request this server answers\n")
    end
    local path, query = string.match(target, "^([^?]*)%??(.*)$")
    if not string.find(target, "?", 1, true) then query = nil end
    local fields, count = query_fields(query)
    for _, route in ipairs(fields and M.ROUTES or {}) do
        local argument = route.match(path, fields, count)
        if argument ~= nil then
            if method ~= "GET" then
                self.run:count("refused-method")
                return respond(client, 405, "only GET is answered here\n", { "Allow: GET" })
            end
            self.run:count("requests-" .. route.name)
            return route.handle(self, client, argument)
        end
    end
    self.run:count("refused-not-found")
    return respond(client, 404, "not found\n")
end
-- }}}

-- {{{ function Server:linger()
-- Closing a socket with unread bytes in it makes the system reset the
-- connection, and the client may lose the answer already sent. So an
-- answered socket is shut for sending, and what the client still sends is
-- read and dropped until it closes too, for at most a second.
function Server:linger(sock)
    sock:shutdown("send")
    self.closing[#self.closing + 1] = { sock = sock, deadline = socket.gettime() + 1 }
end
-- }}}

-- {{{ function Server:close()
function Server:close(client, status)
    self:log_request(client, status)
    self:linger(client.sock)
    for index, other in ipairs(self.clients) do
        if other == client then table.remove(self.clients, index) break end
    end
end
-- }}}

-- {{{ function Server:resume()
-- Runs a connection's coroutine until it yields again or ends.
function Server:resume(client, event)
    local ok, kind, deadline = coroutine.resume(client.co, event)
    if not ok then
        self.run:log("a connection failed: " .. tostring(kind))
        self.run:count("connections-failed")
        return self:close(client, 500)
    end
    if coroutine.status(client.co) == "dead" then
        return self:close(client, kind)
    end
    client.state, client.deadline = kind, deadline
end
-- }}}

-- {{{ function Server:accept()
function Server:accept()
    while true do
        local sock = self.listener:accept()
        if not sock then return end
        sock:settimeout(0)
        local address = sock:getpeername() or "?"
        local client = { sock = sock, address = address,
                         deadline = socket.gettime() + self.settings["request-seconds"] }
        if #self.clients >= self.settings["max-connections"] then
            self.run:count("refused-too-many")
            respond(client, 503, "too many connections; try again\n")
            self:log_request(client, 503)
            self:linger(sock)
        else
            self.clients[#self.clients + 1] = client
            client.co = coroutine.create(function(event) return serve(self, client, event) end)
            self:resume(client, "start")
        end
    end
end
-- }}}

-- {{{ function Server:tick()
-- One turn of the loop: wait up to `seconds` for a socket to be readable,
-- accept, read, notice a new version, and answer whatever is due.
function Server:tick(seconds)
    local watched = { self.listener }
    for _, client in ipairs(self.clients) do watched[#watched + 1] = client.sock end
    for _, done in ipairs(self.closing) do watched[#watched + 1] = done.sock end
    local readable = socket.select(watched, nil, seconds)
    local ready = {}
    for _, sock in ipairs(readable or {}) do ready[sock] = true end

    if ready[self.listener] then self:accept() end
    local now = socket.gettime()
    -- answered sockets: drop what they send until they close, or time is up
    local still = {}
    for _, done in ipairs(self.closing) do
        local closed = false
        if ready[done.sock] then
            local _, problem = done.sock:receive(4096)
            closed = problem == "closed"
        end
        if closed or now >= done.deadline then done.sock:close() else still[#still + 1] = done end
    end
    self.closing = still
    local new_version = false
    if now >= self.next_check then
        new_version = self:refresh()
        self.next_check = now + self.settings["check-seconds"]
    end
    -- a copy: clients leave the list as they finish
    local clients = {}
    for index, client in ipairs(self.clients) do clients[index] = client end
    for _, client in ipairs(clients) do
        if client.state == "read" then
            if ready[client.sock] then self:resume(client, "readable")
            elseif now >= client.deadline then self:resume(client, "late") end
        elseif client.state == "wait" then
            if ready[client.sock] then
                -- a waiting client sends nothing more: readable means it left
                local _, problem = client.sock:receive(1)
                if problem == "closed" then self:resume(client, "gone") end
            end
            if client.state == "wait" and client.co and coroutine.status(client.co) ~= "dead" then
                if new_version then self:resume(client, "version")
                elseif now >= client.deadline then self:resume(client, "late") end
            end
        end
    end
end
-- }}}

-- {{{ function Server:stopped()
function Server:stopped()
    local handle = io.open(self.stop_file, "r")
    if handle then
        handle:close()
        os.remove(self.stop_file)
        self.run:log("stop file found")
        return true
    end
    return false
end
-- }}}

-- {{{ function Server:finish()
function Server:finish()
    for _, client in ipairs(self.clients) do client.sock:close() end
    for _, done in ipairs(self.closing) do done.sock:close() end
    self.clients, self.closing = {}, {}
    self.listener:close()
    return self.run:finish()
end
-- }}}
-- }}}

-- {{{ function M.new()
-- A server on a project root: settings read, run started, listening.
-- opts: root, clock (tests).
function M.new(opts)
    opts = opts or {}
    local root = opts.root or DIR
    -- loaded here, not at the top: 076 run as a program (add-viewer) loads this file
    page = page or dofile(DIR .. "/src/076-html-page.lua")
    local values = settings.read("canvas-server", M.SETTINGS, { root = root })
    local viewers_path, problem = page.viewers_path(values["viewers-file"], root)
    if not viewers_path then error("canvas-server: " .. problem, 0) end
    local page_html = page.build(root)
    local run = goodbye.start("canvas-server", { root = root, clock = opts.clock })
    local listener = assert(socket.bind(values["listen-address"], values["port"]))
    listener:settimeout(0)
    local address, port = listener:getsockname()
    local locals = {}
    for _, name in ipairs(values["local-addresses"]) do locals[name] = true end
    local self = setmetatable({
        root = root, run = run, settings = values, listener = listener,
        address = address, port = tonumber(port), clients = {}, closing = {}, locals = locals,
        canvas_folder = root .. "/tmp/shared-memory/canvas",
        stop_file = root .. "/tmp/shared-memory/canvas-server.stop",
        next_check = 0, viewers_path = viewers_path, page_html = page_html,
        sessions = page.sessions({ seconds = values["session-seconds"],
                                   most = values["max-sessions"] }),
    }, Server)
    os.remove(self.stop_file)
    self:refresh()
    run:log(string.format("listening on %s:%d; at most %d connections, %d bytes a request, "
        .. "%s seconds for it to arrive; waits last %s seconds", address, self.port,
        values["max-connections"], values["max-request-bytes"], values["request-seconds"],
        values["wait-seconds"]))
    run:log("a new version is noticed by reading canvas/current every "
        .. values["check-seconds"] .. " seconds (no inotify binding in this project)")
    local viewers, viewers_problem = page.read_viewers(viewers_path)
    local names = {}
    for name in pairs(viewers or {}) do names[#names + 1] = name end
    table.sort(names)
    run:log(string.format("the page is %d bytes; viewers in %s: %s; plain text goes to %s",
        #page_html, viewers_path,
        viewers and (#names > 0 and table.concat(names, " ") or "none yet (scripts/add-viewer)")
            or ("unreadable: " .. viewers_problem),
        ({ ["local"] = "the four machines only", everyone = "everyone",
           nobody = "no one" })[values["send-plain"]]))
    return self
end
-- }}}

-- {{{ function M.main()
function M.main(opts)
    local self = M.new(opts)
    while not self:stopped() do
        self:tick(0.1)
    end
    return self:finish()
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "025%-canvas%-server%.lua$") then
    local root
    for index = 1, #arg do
        if arg[index] == "--dir" then root = arg[index + 1] end
    end
    M.main({ root = root })
end
-- }}}

return M
