# Issue 101: Basic HTTP Server and Screen Capture

## Status
- [x] Completed (2026-03-27)

## Current Behavior
No implementation exists. Empty project directory.

## Intended Behavior
A working HTTP server that:
1. Captures the current screen as a JPEG image
2. Serves it at `/screen` endpoint
3. Accepts a peer address to fetch their screen
4. Displays byte transfer statistics

Both peers run the same server, creating a symmetric screen-sharing system.

## Suggested Implementation Steps

1. **001-config.lua**: Create configuration module
   - Port number (default 8080)
   - Peer address (configurable)
   - Capture quality settings
   - Framerate settings

2. **002-server.lua**: HTTP server using luasocket
   - Listen on configured port
   - Route `/screen` to serve current screenshot
   - Route `/stats` to show byte transfer info
   - Handle incoming connections

3. **003-capture.lua**: Screen capture using ffmpeg
   - Capture X11 display to JPEG
   - Return raw bytes
   - Track capture timing

4. **004-encode.lua**: Byte handling utilities
   - Read file as bytes
   - Format bytes as hex dump
   - Calculate transfer statistics

5. **005-display.lua**: Display received screen
   - Save received bytes to file
   - Open in image viewer or convert to ASCII

6. **006-main.lua**: Main entry point
   - Parse command line args
   - Start server
   - Optionally start client polling

7. **run.sh**: Launcher script
   - Set DIR variable
   - Check dependencies
   - Launch with luajit

## Dependencies
- luasocket (TCP/HTTP)
- ffmpeg (screen capture)
- luajit (runtime)

## Related Documents
- notes/vision
- docs/001-roadmap.md

## Completion Notes

All implementation steps completed successfully:

1. **001-config.lua**: Configuration with hardcoded project path, argument parsing, luasocket path setup
2. **002-server.lua**: TCP server using luasocket, HTTP request parsing, response handling
3. **003-capture.lua**: Screen capture via ffmpeg x11grab, JPEG encoding
4. **004-encode.lua**: Hex dump, byte formatting, JPEG header parsing, statistics
5. **005-display.lua**: Save/view received images, ASCII preview support
6. **006-main.lua**: Main loop with HTTP handlers and optional peer polling
7. **run.sh**: Launcher with dependency checks and help

### Test Results
- Server binds to port and accepts HTTP connections
- `/` returns index HTML page
- `/screen` returns current screenshot as JPEG (~175KB for 1920x1080)
- `/bytes` returns hex dump showing raw JPEG bytes
- `/stats` returns transfer statistics
- `/live` provides auto-refreshing browser view

### Lessons Learned
- Path detection via debug.getinfo is unreliable with relative paths; hardcoded paths are simpler
- luasocket's non-blocking accept with short timeout + sleep prevents CPU spin
