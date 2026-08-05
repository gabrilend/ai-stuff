#!/usr/bin/env luajit
-- Main entry point for screen-record-stream
-- Runs HTTP server and optionally polls peer for their screen

-- {{{ setup paths and require modules

-- Hardcoded project directory
-- Why: Reliable path regardless of how script is invoked
local DIR = "/mnt/mtwo/programming/ai-stuff/screen-record-stream/"

-- Add src to package path before requiring modules
package.path = DIR .. "src/?.lua;" .. package.path

local config = require("001-config")

-- Override DIR with detected path (config may have wrong path if loaded differently)
-- Why: Ensure consistent paths regardless of how script is invoked
config.DIR = DIR
config.tmp_dir = DIR .. "tmp/"
config.output_dir = DIR .. "output/"

config.parse_args(arg)
config.setup_paths()

local server = require("002-server")
local capture = require("003-capture")
local encode = require("004-encode")
local display = require("005-display")
local stream = require("007-stream")
local diff = require("008-diff")

local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Initialize streaming
stream.init(config)
diff.reset()
-- }}}

-- {{{ HTTP Handlers

-- {{{ handler_screen
local function handler_screen(client, method, headers, body, cfg)
    -- Serve current screenshot as JPEG
    -- GET /screen -> returns JPEG image
    local data, err = capture.screenshot(cfg)
    if not data then
        server.send_response(client, 500, "text/plain", "Capture failed: " .. tostring(err))
        return
    end

    cfg.stats.bytes_sent = cfg.stats.bytes_sent + #data
    cfg.stats.frames_sent = cfg.stats.frames_sent + 1

    -- Show what we're sending
    local info = encode.jpeg_info(data)
    print(string.format(
        "[screen] Sending %s (%dx%d)",
        encode.format_bytes(#data),
        info and info.width or 0,
        info and info.height or 0
    ))

    server.send_binary(client, 200, "image/jpeg", data)
end
-- }}}

-- {{{ handler_stats
local function handler_stats(client, method, headers, body, cfg)
    -- Return current transfer statistics
    -- GET /stats -> returns text stats
    local stats_text = encode.stats_string(cfg)
    server.send_response(client, 200, "text/plain", stats_text)
end
-- }}}

-- {{{ handler_bytes
local function handler_bytes(client, method, headers, body, cfg)
    -- Return hex dump of current screenshot (for visibility into encoding)
    -- GET /bytes -> returns hex dump text
    local data, err = capture.screenshot(cfg)
    if not data then
        server.send_response(client, 500, "text/plain", "Capture failed: " .. tostring(err))
        return
    end

    local hex = encode.hex_dump(data, 16, 512)
    local info = encode.jpeg_info(data)

    local response = string.format(
        "=== Screenshot Bytes ===\n" ..
        "Size: %s\n" ..
        "Dimensions: %dx%d\n" ..
        "First 512 bytes:\n\n%s\n",
        encode.format_bytes(#data),
        info and info.width or 0,
        info and info.height or 0,
        hex
    )

    server.send_response(client, 200, "text/plain", response)
end
-- }}}

-- {{{ handler_index
local function handler_index(client, method, headers, body, cfg)
    -- Index page with links
    local html = [[
<!DOCTYPE html>
<html>
<head><title>Screen Stream</title></head>
<body style="font-family: monospace; background: #1a1a1a; color: #00ff00; padding: 20px;">
<h1>Screen Record Stream</h1>

<h2>Phase 1: Single Frame</h2>
<ul>
<li><a href="/screen">/screen</a> - Current screenshot (JPEG)</li>
<li><a href="/bytes">/bytes</a> - Hex dump of screenshot bytes</li>
<li><a href="/stats">/stats</a> - Transfer statistics</li>
<li><a href="/live">/live</a> - Auto-refreshing live view (polling)</li>
</ul>

<h2>Phase 2: Streaming</h2>
<ul>
<li><a href="/live-stream">/live-stream</a> - Live stream with SSE (recommended)</li>
<li><a href="/stream">/stream</a> - Raw SSE event stream</li>
<li><a href="/stream-stats">/stream-stats</a> - Streaming statistics</li>
</ul>

<p>Peer: ]] .. (cfg.peer_host or "(not configured)") .. ":" .. cfg.peer_port .. [[</p>
<p>Target FPS: ]] .. cfg.target_fps .. [[</p>
</body>
</html>
]]
    server.send_response(client, 200, "text/html", html)
end
-- }}}

-- {{{ handler_live
local function handler_live(client, method, headers, body, cfg)
    -- Auto-refreshing live view
    local html = [[
<!DOCTYPE html>
<html>
<head>
<title>Live Screen</title>
<style>
body { margin: 0; background: #000; }
img { max-width: 100%; height: auto; }
#info { position: fixed; top: 10px; left: 10px; color: #0f0; font-family: monospace; background: rgba(0,0,0,0.7); padding: 5px; }
</style>
</head>
<body>
<div id="info">Loading...</div>
<img id="screen" src="/screen">
<script>
var img = document.getElementById('screen');
var info = document.getElementById('info');
var frames = 0;
setInterval(function() {
    img.src = '/screen?' + Date.now();
    frames++;
    info.textContent = 'Frame: ' + frames + ' | ' + new Date().toLocaleTimeString();
}, 1000);
</script>
</body>
</html>
]]
    server.send_response(client, 200, "text/html", html)
end
-- }}}

-- {{{ handler_stream
local function handler_stream(client, method, headers, body, cfg)
    -- Server-Sent Events stream of screen updates
    -- GET /stream -> SSE stream with base64-encoded JPEG frames
    -- Why: Allows efficient streaming with change detection
    client:settimeout(0.1)

    -- Send SSE headers
    local header =
        "HTTP/1.1 200 OK\r\n" ..
        "Content-Type: text/event-stream\r\n" ..
        "Cache-Control: no-cache\r\n" ..
        "Connection: keep-alive\r\n" ..
        "Access-Control-Allow-Origin: *\r\n" ..
        "\r\n"

    local sent, err = client:send(header)
    if not sent then
        print("[stream] Failed to send headers: " .. tostring(err))
        return
    end

    print("[stream] Client connected, starting stream")

    local frame_count = 0
    local start_time = socket.gettime()
    local last_keyframe = 0

    while true do
        -- Capture frame
        local data, capture_err = capture.screenshot(cfg)
        if not data then
            -- Send error event
            local event = "event: error\ndata: " .. tostring(capture_err) .. "\n\n"
            client:send(event)
            socket.sleep(1)
        else
            -- Check if frame changed or if keyframe is due
            local is_keyframe = (frame_count - last_keyframe) >= cfg.keyframe_interval
            local changed = diff.has_changed(data) or is_keyframe

            if changed then
                if is_keyframe then
                    last_keyframe = frame_count
                    diff.force_keyframe()
                end

                -- Base64 encode the JPEG
                -- Why: SSE is text-based, need to encode binary
                local mime = require("mime")
                local b64 = mime.b64(data)

                -- Send frame as SSE event
                local event = string.format(
                    "event: frame\ndata: {\"index\":%d,\"size\":%d,\"keyframe\":%s,\"data\":\"%s\"}\n\n",
                    frame_count,
                    #data,
                    is_keyframe and "true" or "false",
                    b64
                )

                sent, err = client:send(event)
                if not sent then
                    print(string.format("[stream] Client disconnected after %d frames", frame_count))
                    break
                end

                cfg.stats.bytes_sent = cfg.stats.bytes_sent + #data
                cfg.stats.frames_sent = cfg.stats.frames_sent + 1
            end

            frame_count = frame_count + 1
        end

        -- Rate limiting
        local interval = 1.0 / cfg.target_fps
        socket.sleep(interval)

        -- Check for timeout
        if socket.gettime() - start_time > cfg.stream_timeout then
            print("[stream] Timeout reached, closing connection")
            client:send("event: timeout\ndata: stream ended\n\n")
            break
        end
    end
end
-- }}}

-- {{{ handler_stream_stats
local function handler_stream_stats(client, method, headers, body, cfg)
    -- Return streaming and diff statistics
    local stream_stats = stream.get_stats()
    local diff_stats = diff.get_stats()

    local response = string.format(
        "=== Streaming Statistics ===\n" ..
        "Buffer: %d/%d frames\n" ..
        "Total captured: %d frames\n" ..
        "Capture errors: %d\n" ..
        "\n=== Change Detection ===\n" ..
        "Changed frames: %d\n" ..
        "Unchanged frames: %d\n" ..
        "Change ratio: %.1f%%\n" ..
        "Bandwidth saved: ~%.1f%%\n",
        stream_stats.buffer_count,
        stream_stats.buffer_capacity,
        stream_stats.total_frames,
        stream_stats.capture_errors,
        diff_stats.changes,
        diff_stats.no_changes,
        diff_stats.change_ratio * 100,
        (1 - diff_stats.change_ratio) * 100
    )

    server.send_response(client, 200, "text/plain", response)
end
-- }}}

-- {{{ handler_live_stream
local function handler_live_stream(client, method, headers, body, cfg)
    -- Live view using SSE streaming
    -- Why: More efficient than polling /screen repeatedly
    local html = [[
<!DOCTYPE html>
<html>
<head>
<title>Live Stream</title>
<style>
body { margin: 0; background: #000; overflow: hidden; }
#screen { max-width: 100vw; max-height: 100vh; display: block; margin: auto; }
#info {
    position: fixed; top: 10px; left: 10px;
    color: #0f0; font-family: monospace;
    background: rgba(0,0,0,0.8); padding: 10px;
    font-size: 14px; line-height: 1.4;
}
#bytes {
    position: fixed; bottom: 10px; left: 10px;
    color: #0a0; font-family: monospace;
    background: rgba(0,0,0,0.8); padding: 10px;
    font-size: 11px; max-width: 600px;
    white-space: pre; overflow: hidden;
}
</style>
</head>
<body>
<div id="info">Connecting...</div>
<div id="bytes"></div>
<img id="screen">
<script>
var img = document.getElementById('screen');
var info = document.getElementById('info');
var bytesDiv = document.getElementById('bytes');
var frames = 0;
var bytes = 0;
var startTime = Date.now();

var es = new EventSource('/stream');

es.addEventListener('frame', function(e) {
    var data = JSON.parse(e.data);
    img.src = 'data:image/jpeg;base64,' + data.data;
    frames++;
    bytes += data.size;

    var elapsed = (Date.now() - startTime) / 1000;
    var fps = frames / elapsed;
    var kbps = (bytes / elapsed) / 1024;

    info.innerHTML =
        'Frame: ' + frames + ' | ' +
        'FPS: ' + fps.toFixed(1) + ' | ' +
        'Size: ' + (data.size / 1024).toFixed(1) + ' KB | ' +
        'Bandwidth: ' + kbps.toFixed(1) + ' KB/s' +
        (data.keyframe ? ' [KEYFRAME]' : '');

    // Show first 64 bytes as hex
    var raw = atob(data.data);
    var hex = '';
    for (var i = 0; i < Math.min(64, raw.length); i++) {
        hex += raw.charCodeAt(i).toString(16).padStart(2, '0') + ' ';
        if ((i + 1) % 16 === 0) hex += '\n';
    }
    bytesDiv.textContent = 'First 64 bytes:\n' + hex;
});

es.addEventListener('error', function(e) {
    info.textContent = 'Stream error: ' + (e.data || 'connection lost');
});

es.addEventListener('timeout', function(e) {
    info.textContent = 'Stream ended (timeout)';
    es.close();
});
</script>
</body>
</html>
]]
    server.send_response(client, 200, "text/html", html)
end
-- }}}

-- }}}

-- {{{ Peer polling

-- {{{ function fetch_peer_screen
local function fetch_peer_screen(cfg)
    -- Fetch screen from peer and save it
    if not cfg.peer_host then
        return nil, "no peer configured"
    end

    local url = string.format("http://%s:%d/screen", cfg.peer_host, cfg.peer_port)
    local response_body = {}

    local start_time = socket.gettime()

    local result, status, headers = http.request{
        url = url,
        sink = ltn12.sink.table(response_body),
        method = "GET",
    }

    if not result or status ~= 200 then
        return nil, "fetch failed: " .. tostring(status)
    end

    local data = table.concat(response_body)
    local elapsed = socket.gettime() - start_time

    cfg.stats.bytes_received = cfg.stats.bytes_received + #data
    cfg.stats.frames_received = cfg.stats.frames_received + 1
    cfg.stats.last_receive_time = elapsed

    -- Save to output
    local output_path = cfg.output_dir .. "peer_screen.jpg"
    display.save(data, output_path)

    local info = encode.jpeg_info(data)
    print(string.format(
        "[peer] Received %s (%dx%d) in %.3fs",
        encode.format_bytes(#data),
        info and info.width or 0,
        info and info.height or 0,
        elapsed
    ))

    return data, elapsed
end
-- }}}

-- }}}

-- {{{ Main loop

local handlers = {
    ["/"] = handler_index,
    ["/screen"] = handler_screen,
    ["/stats"] = handler_stats,
    ["/bytes"] = handler_bytes,
    ["/live"] = handler_live,
    ["/stream"] = handler_stream,
    ["/stream-stats"] = handler_stream_stats,
    ["/live-stream"] = handler_live_stream,
}

-- {{{ function main
local function main()
    print("=== Screen Record Stream ===")
    print("Directory: " .. config.DIR)
    print("Port: " .. config.port)
    print("Peer: " .. (config.peer_host or "(none)") .. ":" .. config.peer_port)
    print("Target FPS: " .. config.target_fps)
    print("")

    -- Ensure tmp and output dirs exist
    os.execute("mkdir -p " .. config.tmp_dir)
    os.execute("mkdir -p " .. config.output_dir)

    local srv = server.create(config)

    local last_poll = 0
    local viewer_pid = nil

    print("Server running. Press Ctrl+C to stop.")
    print("Open http://localhost:" .. config.port .. "/ in browser")
    print("")

    while true do
        -- Accept incoming connections (non-blocking)
        local client = srv:accept()
        if client then
            server.handle_request(client, config, handlers)
        end

        -- Poll peer if configured
        if config.peer_host then
            local now = socket.gettime()
            if now - last_poll >= config.poll_interval then
                last_poll = now
                local data, err = fetch_peer_screen(config)
                if data then
                    -- Update live viewer if open
                    viewer_pid = display.update_live(config.output_dir .. "peer_screen.jpg", viewer_pid)
                end
            end
        end

        -- Small sleep to prevent CPU spin
        -- Why: Non-blocking accept + polling needs throttling
        socket.sleep(0.01)
    end
end
-- }}}

-- Run
main()
