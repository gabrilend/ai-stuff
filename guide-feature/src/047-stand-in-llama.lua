#!/usr/bin/env luajit
-- 047-stand-in-llama.lua - a stand-in llama.cpp server, for tests only.
--
-- In plain terms: the model caller (046) and the turn's asking loop (404)
-- talk to llama.cpp servers over HTTP. Those servers (issue 401a) run on the
-- owner's machine with real models; this project installs neither here. So
-- the tests start this instead: a small server on 127.0.0.1 that answers the
-- same routes in the same shapes llama-server does, with scripted replies.
-- It listens on the loopback address only, never anything else, and writes
-- the port the system gave it to a file, so tests never fight over a port.
--
-- The routes, as llama-server answers them:
--   GET  /v1/models             {"object":"list","data":[{"id":...}]}
--   POST /v1/chat/completions   {"choices":[{"message":{"role":"assistant",
--                                 "content":...}}], "usage":{...}}
--   POST /tokenize              {"tokens":[...]}  (one token per word here)
--   POST /v1/embeddings         {"data":[{"index":0,"embedding":[...]}]}
--                               (listed last first; index says which text)
-- A chat server answers /v1/embeddings with 501 and an embedding server
-- answers /v1/chat/completions with 501, as llama-server does with and
-- without --embeddings. Errors are llama-server's {"error":{...}} body.
--
-- Chat replies come from a JSON file, a list taken in order; the last one is
-- repeated when the list runs out. Each is a string (the reply), or a table:
--   { "content": "...", "delay": 2 }        answered after 2 seconds
--   { "status": 500, "error": "..." }       a server error
--   { "rewrite": "w1 w2 ...", "wide_every": 3 }
--                                           a model doing turns (issue 405):
--     it reads the canvas it was shown (the ruler in the first user turn,
--     049's unruler) and changes one word, the first of a row, to the next
--     of the words (on a blank canvas, the word starts a row); row and word move on with every chat request. Every
--     wide_every-th request (when given) its row runs past the edge instead,
--     so the turn has a reply that does not fit and asks again.
--   { "rewrite": ..., "fill": true }      the same, but always on the nth
--     row, starting it with the word when it is empty (issue 602), so the
--     canvas fills up row by row.
--   { "distill": true, "wide_every": 2 }  a distiller (issue 601): the
--     first canvas in the first user turn that holds one, with the changed
--     words listed there applied (M.distill); every wide_every-th request
--     runs past the edge, as above.
-- Every request is appended to a JSON-lines file, so a test can read what the
-- caller sent (the whole conversation, every time).
--
-- With --key-file, it asks for the key in that file as llama-server does with
-- --api-key-file (read from a file, so the key is on no command line): every
-- route but GET /v1/models and /health needs the header
-- "Authorization: Bearer KEY", and a request without it, or with another key,
-- gets 401 and llama-server's "Invalid API Key" body. The request log then
-- says whether each request was `authorized`; it never records the key.
--
-- usage:
--   luajit 047-stand-in-llama.lua --kind chat|embedding --port-file FILE
--          [--replies FILE] [--requests FILE] [--dimensions N] [--parent PID]
--          [--key-file FILE]
--   --parent: leave once that process is gone (a test that died)

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local socket = require("socket")
local ffi = require("ffi")
pcall(ffi.cdef, "int kill(int pid, int sig);")
local json = dofile(DIR .. "/libs/dkjson.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")

local M = {}

-- {{{ M.ADDRESS
-- The only address this ever listens on.
M.ADDRESS = "127.0.0.1"
-- }}}

-- {{{ local function words()
local function words(text)
    local list = {}
    for word in string.gmatch(text or "", "%S+") do list[#list + 1] = word end
    return list
end
-- }}}

-- {{{ local function hash()
-- A small, stable number for a word: its token id and its embedding bucket.
local function hash(text)
    local h = 5381
    for index = 1, #text do
        h = (h * 33 + string.byte(text, index)) % 2147483647
    end
    return h
end
-- }}}

-- {{{ function M.tokens()
-- One token per word: enough for counting, and easy to check by eye.
function M.tokens(text)
    local list = {}
    for _, word in ipairs(words(text)) do list[#list + 1] = hash(word) % 32000 end
    return list
end
-- }}}

-- {{{ function M.embedding()
-- A vector of `dimensions` numbers made from the words, of length 1: the same
-- text always gives the same vector, and texts sharing words lie close.
function M.embedding(text, dimensions)
    local vector = {}
    for index = 1, dimensions do vector[index] = 0 end
    for _, word in ipairs(words(text)) do
        local bucket = hash(string.lower(word)) % dimensions + 1
        vector[bucket] = vector[bucket] + 1
    end
    local length = 0
    for index = 1, dimensions do length = length + vector[index] ^ 2 end
    length = math.sqrt(length)
    if length > 0 then
        for index = 1, dimensions do vector[index] = vector[index] / length end
    end
    return vector
end
-- }}}

-- {{{ local function error_body()
local function error_body(status, message, kind)
    return status, { error = { code = status, message = message, type = kind } }
end
-- }}}

-- {{{ function M.new()
-- A server's state: its kind, its replies, and where requests are written.
function M.new(opts)
    assert(opts.kind == "chat" or opts.kind == "embedding", "--kind chat or embedding")
    local server = { kind = opts.kind, replies = opts.replies or {}, taken = 0,
                     requests = opts.requests, dimensions = opts.dimensions or 8,
                     key = opts.key }
    return setmetatable(server, { __index = M })
end
-- }}}

-- {{{ function M.rewrite()
-- A turn's edit, as the `rewrite` reply makes it: the canvas the model was
-- shown, with the first word of one row changed to one of `words`. The
-- `n`th request picks the row ((n - 1) % height + 1, or the next row with a
-- word on it) and the word (n - 1) % #words + 1, or the next one when that is
-- the word already there. With `wide`, that row runs past the edge. With
-- `fill` (602), the row is always the nth: a row with no word gets the word
-- at its start, so the canvas fills row by row. Pure, so the tests can call
-- it.
function M.rewrite(messages, n, word_text, wide, fill)
    local shown
    for _, message in ipairs(messages) do
        if message.role == "user" then
            shown = prompt.unruler(message.content)
            if shown then break end
        end
    end
    if not shown then return "stand-in: there is no canvas in the conversation" end
    local list = words(word_text)
    if #list == 0 then list = { "word" } end
    -- the nth word, or the next one that is not the word it would replace,
    -- so every edit changes the canvas while there are two words to choose
    local function pick(current)
        for step = 0, #list - 1 do
            local word = list[(n - 1 + step) % #list + 1]
            if word ~= current then return word end
        end
        return list[1]
    end
    local width = utf8.length(shown[1])
    local function place(index, text)
        local cells = utf8.split(text)
        local row = {}
        for at = 1, math.min(#cells, width) do row[at] = cells[at] end
        shown[index] = (table.concat(row):gsub("%s+$", ""))
        if wide then shown[index] = utf8.pad(shown[index], width) .. " past the edge" end
    end
    local placed = false
    -- with `fill`, the nth row itself: its first word changed, or, when it
    -- has none, the word starting it (issue 602)
    if fill then
        local index = (n - 1) % #shown + 1
        local head, current, rest = string.match(shown[index], "^(%s*)(%S+)(.*)$")
        if head then place(index, head .. pick(current) .. rest)
        else place(index, pick(nil)) end
        placed = true
    end
    for step = 0, placed and -1 or #shown - 1 do
        local index = (n - 1 + step) % #shown + 1
        local head, current, rest = string.match(shown[index], "^(%s*)(%S+)(.*)$")
        if head then
            place(index, head .. pick(current) .. rest)
            placed = true
            break
        end
    end
    -- a canvas with no word on it yet: the word starts the row
    if not placed then place((n - 1) % #shown + 1, pick(nil)) end
    for index = 1, #shown do shown[index] = (shown[index]:gsub("%s+$", "")) end
    return table.concat(shown, "\n") .. "\n"
end
-- }}}

-- {{{ function M.distill()
-- A distiller's canvas, as the `distill` reply makes it (issues 601, 602):
-- the first canvas the model was shown (the current one, in 067's prompt),
-- with every changed-word line in that message applied to it in order. A
-- word some voice wrote, standing where that voice wrote it, is *claimed*:
--   `wrote "WORD" at row R, column C` writes the word there, blanking every
--     word it lands on, unless it stands there already, or it lands on a
--     claimed word or on a word written earlier in this distill: then the
--     place is contested and the word written first keeps it;
--   `erased "WORD" at row R, column C` blanks the word where it still
--     stands there and is not claimed.
-- So the canvas takes in every voice's newest changes, even a voice's whose
-- base is behind the current canvas, and the voice listed first keeps a
-- contested place. With `wide`, the first row runs past the edge. Pure, so
-- the tests can call it.
function M.distill(messages, wide)
    local content
    for _, message in ipairs(messages) do
        if message.role == "user" and prompt.unruler(message.content) then
            content = message.content
            break
        end
    end
    if not content then return "stand-in: there is no canvas in the conversation" end
    local shown = prompt.unruler(content)
    local width = utf8.length(shown[1])
    local grid = {}
    for index, row in ipairs(shown) do
        grid[index] = utf8.split(utf8.pad(row, width))
    end
    local lines = {}
    local claimed = {}
    for line in string.gmatch(content, "[^\n]+") do
        local what, word, row, column = string.match(line,
            '^%s*(%a+) "(.*)" at row (%d+), column (%d+)%s*$')
        row, column = tonumber(row), tonumber(column)
        if (what == "erased" or what == "wrote") and grid[row] and column >= 1 then
            lines[#lines + 1] = { what = what, cells = utf8.split(word), text = word,
                                  row = row, column = column }
            if what == "wrote" then claimed[row .. ":" .. column .. ":" .. word] = true end
        end
    end
    local function stands(row, column, cells)
        for offset, cell in ipairs(cells) do
            if grid[row][column + offset - 1] ~= cell then return false end
        end
        return true
    end
    -- the words (runs of non-space cells) on a row that overlap columns
    -- from..to: { start, stop, text }
    local function words_over(row, from, to)
        local found, column = {}, 1
        while column <= width do
            if grid[row][column] ~= " " then
                local stop = column
                while stop < width and grid[row][stop + 1] ~= " " do stop = stop + 1 end
                if stop >= from and column <= to then
                    found[#found + 1] = { start = column, stop = stop,
                        text = table.concat(grid[row], "", column, stop) }
                end
                column = stop + 1
            else
                column = column + 1
            end
        end
        return found
    end
    local placed = {}
    for _, change in ipairs(lines) do
        local row, column, cells = change.row, change.column, change.cells
        local stop = column + #cells - 1
        if change.what == "erased" then
            if stands(row, column, cells) and not claimed[row .. ":" .. column .. ":" .. change.text] then
                for at = column, stop do grid[row][at] = " " end
            end
        elseif stop <= width and not stands(row, column, cells) then
            local contested = false
            local under = words_over(row, column, stop)
            for _, word in ipairs(under) do
                if claimed[row .. ":" .. word.start .. ":" .. word.text] then contested = true end
                for at = word.start, word.stop do
                    if placed[row .. ":" .. at] then contested = true end
                end
            end
            if not contested then
                for _, word in ipairs(under) do
                    for at = word.start, word.stop do grid[row][at] = " " end
                end
                for offset, cell in ipairs(cells) do
                    grid[row][column + offset - 1] = cell
                    placed[row .. ":" .. (column + offset - 1)] = true
                end
            end
        end
    end
    local rows = {}
    for index = 1, #grid do rows[index] = (table.concat(grid[index]):gsub("%s+$", "")) end
    if wide then rows[1] = utf8.pad(rows[1], width) .. " past the edge" end
    return table.concat(rows, "\n") .. "\n"
end
-- }}}

-- {{{ function M:next_reply()
function M:next_reply(messages)
    self.taken = self.taken + 1
    local reply = self.replies[math.min(self.taken, #self.replies)]
    if reply == nil then
        local last = messages[#messages] and messages[#messages].content or ""
        reply = "stand-in reply: " .. (string.match(last, "^[^\n]*") or "")
    end
    if type(reply) == "string" then reply = { content = reply } end
    if reply.rewrite then
        local wide = reply.wide_every and self.taken % reply.wide_every == 0
        reply = { content = M.rewrite(messages, self.taken, reply.rewrite, wide, reply.fill),
                  delay = reply.delay }
    elseif reply.distill then
        local wide = reply.wide_every and self.taken % reply.wide_every == 0
        reply = { content = M.distill(messages, wide), delay = reply.delay }
    end
    return reply
end
-- }}}

-- {{{ function M:answer()
-- What one request gets: a status and a table to send as JSON. Pure, so the
-- tests can call it without a socket. `authorization` is the request's
-- Authorization header, or nil.
local PUBLIC = { ["/v1/models"] = true, ["/health"] = true }
function M:answer(method, path, body_text, authorization)
    local authorized = nil
    if self.key then authorized = authorization == "Bearer " .. self.key end
    local body = nil
    if method == "POST" then
        body = json.decode(body_text or "")
        if type(body) ~= "table" then
            return error_body(400, "the body is not JSON", "invalid_request_error")
        end
    end
    if self.requests then
        local handle = io.open(self.requests, "ab")
        if handle then
            handle:write(json.encode({ method = method, path = path, body = body,
                                       authorized = authorized }), "\n")
            handle:close()
        end
    end

    if authorized == false and not PUBLIC[path] then
        return error_body(401, "Invalid API Key", "authentication_error")
    end

    if method == "GET" and path == "/v1/models" then
        return 200, { object = "list", data = { { id = "stand-in-" .. self.kind,
            object = "model", owned_by = "llamacpp" } } }
    elseif method == "POST" and path == "/tokenize" then
        return 200, { tokens = M.tokens(body.content) }
    elseif method == "POST" and path == "/v1/embeddings" then
        if self.kind ~= "embedding" then
            return error_body(501, "This server does not support embeddings. "
                .. "Start it with `--embeddings`", "not_supported_error")
        end
        local inputs = type(body.input) == "table" and body.input or { body.input }
        local data, tokens = {}, 0
        -- Listed last first: the API ties each vector to its text by `index`,
        -- not by place, so a caller that goes by place is caught here.
        for index, text in ipairs(inputs) do
            data[#inputs - index + 1] = { object = "embedding", index = index - 1,
                                          embedding = M.embedding(text, self.dimensions) }
            tokens = tokens + #words(text)
        end
        return 200, { object = "list", model = body.model, data = data,
                      usage = { prompt_tokens = tokens, total_tokens = tokens } }
    elseif method == "POST" and path == "/v1/chat/completions" then
        if self.kind ~= "chat" then
            return error_body(501, "This server does not support completions. "
                .. "Start it without `--embeddings`", "not_supported_error")
        end
        local messages = type(body.messages) == "table" and body.messages or {}
        local reply = self:next_reply(messages)
        if reply.delay then socket.sleep(reply.delay) end
        if reply.status then
            return error_body(reply.status, reply.error or "stand-in error", "server_error")
        end
        local prompt = 0
        for _, message in ipairs(messages) do prompt = prompt + #words(message.content) end
        local completion = #words(reply.content)
        return 200, {
            object = "chat.completion", model = body.model,
            choices = { { index = 0, finish_reason = "stop",
                          message = { role = "assistant", content = reply.content } } },
            usage = { prompt_tokens = prompt, completion_tokens = completion,
                      total_tokens = prompt + completion },
        }
    end
    return error_body(404, "File Not Found", "not_found_error")
end
-- }}}

-- {{{ local function read_request()
-- One HTTP request from a connected socket: method, path, body and its
-- Authorization header.
local function read_request(client)
    client:settimeout(10)
    local line = client:receive("*l")
    if not line then return nil end
    local method, path = string.match(line, "^(%u+)%s+(%S+)")
    local length, authorization = 0, nil
    while true do
        local header = client:receive("*l")
        if not header or header == "" then break end
        local value = string.match(string.lower(header), "^content%-length:%s*(%d+)")
        if value then length = tonumber(value) end
        local given = string.match(header, "^[Aa]uthorization:%s*(.-)%s*$")
        if given then authorization = given end
    end
    local body = length > 0 and client:receive(length) or ""
    return method, path, body, authorization
end
-- }}}

-- {{{ function M:serve()
-- Listens on 127.0.0.1, on the port the system gives, writes that port to
-- `port_file` (under a temporary name, then renamed, so it is never read half
-- written), and answers one request at a time until it is killed, or until
-- the process `parent` is gone.
function M:serve(port_file, parent)
    local listener = assert(socket.bind(M.ADDRESS, 0))
    listener:settimeout(1)
    local _, port = listener:getsockname()
    local handle = assert(io.open(port_file .. ".part", "wb"))
    handle:write(tostring(port), "\n")
    handle:close()
    assert(os.rename(port_file .. ".part", port_file))
    while true do
        -- A test that dies without stopping its stand-ins leaves none behind:
        -- with --parent, the server leaves once that process is gone.
        if parent and ffi.C.kill(parent, 0) ~= 0 and ffi.errno() ~= 1 then
            listener:close()
            return
        end
        local client = listener:accept()
        if client then
            local method, path, body, authorization = read_request(client)
            if method then
                local status, reply = self:answer(method, path, body, authorization)
                local text = json.encode(reply)
                client:send(string.format("HTTP/1.1 %d %s\r\nContent-Type: application/json\r\n"
                    .. "Content-Length: %d\r\nConnection: close\r\n\r\n%s",
                    status, status == 200 and "OK" or "Error", #text, text))
            end
            client:close()
        end
    end
end
-- }}}

-- {{{ command line
if arg and arg[0] and string.match(arg[0], "047%-stand%-in%-llama%.lua$") then
    local opts, port_file = {}, nil
    local index = 1
    while arg[index] do
        local name, value = arg[index], arg[index + 1]
        if name == "--kind" then opts.kind = value
        elseif name == "--port-file" then port_file = value
        elseif name == "--requests" then opts.requests = value
        elseif name == "--dimensions" then opts.dimensions = tonumber(value)
        elseif name == "--parent" then opts.parent = tonumber(value)
        elseif name == "--key-file" then
            local handle = assert(io.open(value, "rb"))
            opts.key = assert(string.match(handle:read("*a"), "^%s*(%S+)%s*$"),
                "--key-file holds no key")
            handle:close()
        elseif name == "--replies" then
            local handle = assert(io.open(value, "rb"))
            opts.replies = assert(json.decode(handle:read("*a")), "--replies is not JSON")
            handle:close()
        elseif name ~= "--dir" then
            io.stderr:write("unknown argument: ", name, "\n")
            os.exit(2)
        end
        index = index + 2
    end
    if not port_file then
        io.stderr:write("usage: 047-stand-in-llama.lua --kind chat|embedding --port-file FILE"
            .. " [--replies FILE] [--requests FILE] [--dimensions N] [--parent PID]"
            .. " [--key-file FILE]\n")
        os.exit(2)
    end
    M.new(opts):serve(port_file, opts.parent)
end
-- }}}

return M
