-- HTTP Server module for screen-record-stream
-- Handles incoming connections and serves screen data over HTTP

local socket = require("socket")

local server = {}

-- {{{ function server.create
function server.create(config)
    -- Create and bind a TCP server socket
    -- Returns: server object with accept/close methods
    local tcp = assert(socket.tcp())

    -- Allow port reuse to avoid "address already in use" errors
    -- Why: Speeds up development cycle when restarting server
    tcp:setoption("reuseaddr", true)

    local ok, err = tcp:bind(config.bind_address, config.port)
    if not ok then
        error("Failed to bind to " .. config.bind_address .. ":" .. config.port .. " - " .. err)
    end

    tcp:listen(5)
    tcp:settimeout(0.1)  -- Non-blocking accept

    print("[server] Listening on " .. config.bind_address .. ":" .. config.port)

    return {
        socket = tcp,
        config = config,

        accept = function(self)
            return self.socket:accept()
        end,

        close = function(self)
            self.socket:close()
        end
    }
end
-- }}}

-- {{{ function server.parse_request
function server.parse_request(client)
    -- Read and parse an HTTP request from client socket
    -- Returns: method, path, headers table, body
    local line, err = client:receive("*l")
    if not line then
        return nil, nil, nil, nil, err
    end

    local method, path, version = line:match("^(%S+)%s+(%S+)%s+(%S+)")
    if not method then
        return nil, nil, nil, nil, "malformed request line"
    end

    -- Read headers
    local headers = {}
    while true do
        line, err = client:receive("*l")
        if not line or line == "" then
            break
        end
        local key, value = line:match("^([^:]+):%s*(.*)$")
        if key then
            headers[key:lower()] = value
        end
    end

    -- Read body if Content-Length present
    local body = nil
    if headers["content-length"] then
        local len = tonumber(headers["content-length"])
        if len and len > 0 then
            body, err = client:receive(len)
        end
    end

    return method, path, headers, body, nil
end
-- }}}

-- {{{ function server.send_response
function server.send_response(client, status, content_type, body, extra_headers)
    -- Send an HTTP response to client
    -- extra_headers: optional table of additional headers
    local status_text = {
        [200] = "OK",
        [404] = "Not Found",
        [500] = "Internal Server Error",
    }

    local response = string.format(
        "HTTP/1.1 %d %s\r\n" ..
        "Content-Type: %s\r\n" ..
        "Content-Length: %d\r\n" ..
        "Connection: close\r\n",
        status,
        status_text[status] or "Unknown",
        content_type,
        #body
    )

    if extra_headers then
        for k, v in pairs(extra_headers) do
            response = response .. k .. ": " .. v .. "\r\n"
        end
    end

    response = response .. "\r\n" .. body

    local bytes_sent = client:send(response)
    return bytes_sent
end
-- }}}

-- {{{ function server.send_binary
function server.send_binary(client, status, content_type, body)
    -- Send binary data (like JPEG) with proper headers
    -- Shows raw byte count in header for visibility
    local header = string.format(
        "HTTP/1.1 %d OK\r\n" ..
        "Content-Type: %s\r\n" ..
        "Content-Length: %d\r\n" ..
        "X-Raw-Bytes: %d\r\n" ..
        "Connection: close\r\n" ..
        "\r\n",
        status,
        content_type,
        #body,
        #body
    )

    local bytes_sent = 0
    local sent, err = client:send(header)
    if sent then bytes_sent = bytes_sent + sent end

    sent, err = client:send(body)
    if sent then bytes_sent = bytes_sent + sent end

    return bytes_sent
end
-- }}}

-- {{{ function server.handle_request
function server.handle_request(client, config, handlers)
    -- Main request handler - routes to appropriate handler function
    -- handlers: table mapping paths to handler functions
    client:settimeout(5)

    local method, path, headers, body, err = server.parse_request(client)
    if err then
        print("[server] Parse error: " .. err)
        client:close()
        return
    end

    print(string.format("[server] %s %s", method, path))

    -- Find handler for this path
    local handler = handlers[path]
    if handler then
        local ok, result = pcall(handler, client, method, headers, body, config)
        if not ok then
            print("[server] Handler error: " .. tostring(result))
            server.send_response(client, 500, "text/plain", "Internal Server Error: " .. tostring(result))
        end
    else
        server.send_response(client, 404, "text/plain", "Not Found: " .. path)
    end

    client:close()
end
-- }}}

return server
