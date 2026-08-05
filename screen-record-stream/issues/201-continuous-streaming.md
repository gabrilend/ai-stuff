# Issue 201: Continuous Streaming

## Status
- [ ] In Progress

## Current Behavior
Phase 1 provides single-shot screen capture. Server captures on each `/screen` request. Peer polling fetches one frame per poll interval. No frame differencing - full frames sent every time.

## Intended Behavior
Continuous streaming with:
1. Background capture loop producing frames at configurable FPS
2. Frame differencing - only send changed regions to reduce bandwidth
3. Smooth display of received frames in viewer window
4. Bidirectional streaming - both peers send and receive simultaneously

## Suggested Implementation Steps

1. **007-stream.lua**: Streaming module
   - Ring buffer for captured frames
   - Background capture coroutine
   - Frame timestamp tracking

2. **008-diff.lua**: Frame differencing
   - Compare consecutive frames
   - Identify changed regions (tile-based)
   - Encode only changed tiles
   - Reconstruct full frame from base + diffs

3. **Update 006-main.lua**:
   - Add `/stream` endpoint for continuous frames
   - Server-sent events (SSE) or chunked transfer
   - Improved peer polling with frame assembly

4. **Update 005-display.lua**:
   - Continuous viewer update
   - Frame buffer for smooth playback
   - FPS counter display

5. **Add configuration options**:
   - target_fps (default 10)
   - tile_size for differencing (default 64x64)
   - diff_threshold (pixel change threshold)

## Technical Notes

### Frame Differencing Approach
- Divide frame into NxN tiles (e.g., 64x64 pixels)
- Compare each tile's hash with previous frame
- Only transmit tiles that changed
- Client reconstructs: base frame + apply changed tiles

### Streaming Protocol
Option A: Server-Sent Events (SSE)
- Text-based, easy to implement
- Each event contains: tile coordinates + base64 image data

Option B: Chunked HTTP
- Binary-friendly
- Custom framing: [tile_x][tile_y][length][jpeg_data]

### Bandwidth Estimation
- Full 1920x1080 JPEG: ~175KB
- 30x17 = 510 tiles at 64x64
- If 10% change per frame: ~17KB per update
- At 10 FPS: ~170KB/s vs 1.75MB/s for full frames

## Dependencies
- Phase 1 complete (issue 101)

## Related Documents
- docs/001-roadmap.md
- issues/completed/101-basic-http-server-and-screen-capture.md
