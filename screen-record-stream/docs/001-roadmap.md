# Screen Record Stream - Roadmap

## Phase 1: Foundation

**Goal**: Get bytes flowing between two machines.

1. Create basic HTTP server using luasocket
2. Implement screen capture using ffmpeg/scrot
3. Serve screenshot as raw bytes via HTTP endpoint
4. Client-side fetch and save of remote screenshot
5. Phase demo: Two terminals showing successful image transfer

## Phase 2: Streaming

**Goal**: Continuous screen sharing, not just single shots.

1. Capture loop with configurable framerate
2. Frame differencing - only send changed regions
3. Display received frames in viewer window
4. Bidirectional streaming (both send and receive)
5. Phase demo: Live screen share between two machines

## Phase 3: Byte Visibility

**Goal**: Make the protocol visible.

1. Hex dump overlay showing transmitted bytes
2. Encoding statistics display (frame size, compression ratio)
3. Round-trip timing measurements
4. TCP packet boundary visualization
5. Phase demo: Screen share with visible byte stream

## Phase 4: Polish

**Goal**: Production-ready and user-friendly.

1. Configuration file for all settings
2. Auto-discovery on local network (broadcast/multicast)
3. Connection resilience and reconnection
4. Browser-based viewer option
5. Phase demo: Full-featured screen sharing application
