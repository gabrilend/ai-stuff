# 602 — the room server and corridor

phase 6, the room

**Depends on:** 206

## Current behavior

Reels are files.

## Intended behavior

A Lua HTTP server serving a WebXR corridor page with a screen per reel, the reel list polled so new reels appear live.

## Suggested implementation steps

1. Server (luasocket).
2. Page with a browser 3D library from an allowed CDN.
3. Polling.

## Related documents

- docs/datapath-the-room.md
