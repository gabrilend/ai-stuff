# Issue 13-004b: Implement ffmpeg Video Assembly (MVP Sharp Cuts)

## Priority
High (final output of Phase 13 pipeline)

## Parent Issue
13-004: Assemble Video from TTS Audio and Generated Images

## Current Behavior

After 13-004a completes:
- Audio track exists: `output/flopsopoly/trance-track.wav`
- Images exist: `output/flopsopoly/visuals/final/frame_NNNNNN.png`
- Concat file exists: `output/flopsopoly/concat.txt`

No video file exists. The audio and visual outputs are separate.

## Intended Behavior

Use ffmpeg to assemble the concat file and audio track into a single **MP4 video file** with:
- **Sharp cuts** between images (MVP — no transitions)
- Audio synchronized with frame timing
- Standard video codec (H.264) for broad compatibility
- Reasonable file size and quality

### ffmpeg Command

```bash
ffmpeg -y \
    -f concat -safe 0 -i "output/flopsopoly/concat.txt" \
    -i "output/flopsopoly/trance-track.wav" \
    -c:v libx264 -preset medium -crf 23 \
    -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -shortest \
    -movflags +faststart \
    "output/flopsopoly/trance-video.mp4"
```

### Command Breakdown

| Flag | Purpose |
|------|---------|
| `-y` | Overwrite output without asking |
| `-f concat -safe 0` | Use concat demuxer, allow absolute paths |
| `-i concat.txt` | Input: image sequence with durations |
| `-i trance-track.wav` | Input: audio track |
| `-c:v libx264` | Video codec: H.264 |
| `-preset medium` | Encoding speed/quality tradeoff |
| `-crf 23` | Quality (0-51, lower = better, 23 = default) |
| `-pix_fmt yuv420p` | Pixel format for compatibility |
| `-c:a aac` | Audio codec: AAC |
| `-b:a 192k` | Audio bitrate |
| `-shortest` | Stop when shortest input ends |
| `-movflags +faststart` | Move moov atom for streaming |

## Technical Design

```lua
-- {{{ local function assemble_video
local function assemble_video(config)
    local output_dir = config.output_dir or "output/flopsopoly"
    local concat_file = output_dir .. "/concat.txt"
    local audio_file = output_dir .. "/trance-track.wav"
    local video_file = output_dir .. "/trance-video.mp4"

    -- Verify inputs exist
    if not file_exists(concat_file) then
        return false, "Concat file not found: " .. concat_file
    end
    if not file_exists(audio_file) then
        return false, "Audio file not found: " .. audio_file
    end

    -- Verify ffmpeg is available
    local ffmpeg_check = os.execute("ffmpeg -version > /dev/null 2>&1")
    if ffmpeg_check ~= 0 then
        return false, "ffmpeg not found. Install with: sudo apt install ffmpeg"
    end

    -- Build ffmpeg command
    local cmd = string.format([[
        ffmpeg -y \
            -f concat -safe 0 -i "%s" \
            -i "%s" \
            -c:v libx264 -preset %s -crf %d \
            -pix_fmt yuv420p \
            -c:a aac -b:a %s \
            -shortest \
            -movflags +faststart \
            "%s" 2>&1
    ]],
        concat_file,
        audio_file,
        config.preset or "medium",
        config.crf or 23,
        config.audio_bitrate or "192k",
        video_file
    )

    -- Execute with output capture
    io.write("Assembling video... ")
    io.flush()

    local start_time = os.time()
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success = handle:close()
    local elapsed = os.time() - start_time

    if success then
        -- Verify output exists and has reasonable size
        local size = get_file_size(video_file)
        if size > 0 then
            io.write(string.format("done! (%ds, %.1f MB)\n", elapsed, size / 1024 / 1024))
            return true, nil
        else
            return false, "Output file is empty"
        end
    else
        return false, "ffmpeg failed:\n" .. output
    end
end
-- }}}
```

### Duration Verification

After assembly, verify video duration matches audio:

```lua
-- {{{ local function verify_video_duration
local function verify_video_duration(video_file, expected_duration_ms)
    -- Get video duration using ffprobe
    local cmd = string.format(
        'ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "%s"',
        video_file
    )

    local handle = io.popen(cmd)
    local duration_s = tonumber(handle:read("*a"))
    handle:close()

    if not duration_s then
        return false, "Could not determine video duration"
    end

    local video_duration_ms = duration_s * 1000
    local tolerance_ms = 500  -- Allow 500ms tolerance

    if math.abs(video_duration_ms - expected_duration_ms) > tolerance_ms then
        return false, string.format(
            "Duration mismatch: video=%.1fs, expected=%.1fs",
            duration_s, expected_duration_ms / 1000
        )
    end

    return true, nil
end
-- }}}
```

## Suggested Implementation Steps

1. **Check ffmpeg availability** — Error with install instructions if missing
2. **Build ffmpeg command** — From config settings
3. **Execute ffmpeg** — Capture output for error reporting
4. **Verify output** — Check file exists and has non-zero size
5. **Verify duration** — Compare to audio manifest
6. **Report statistics** — File size, duration, encoding time
7. **Add CLI integration** — `--trance-video` flag in `run.sh`

## Deliverables

- [ ] `src/video-assembler.lua` — Main assembly script
- [ ] ffmpeg command construction with config options
- [ ] Output verification (file exists, size > 0, duration matches)
- [ ] Error handling with ffmpeg output capture
- [ ] `output/flopsopoly/trance-video.mp4` — Final video file
- [ ] CLI integration: `--trance-video` flag

## Configuration

```lua
-- In config.lua:
trance_video = {
    output_file = "output/flopsopoly/trance-video.mp4",

    -- Video encoding
    video_codec = "libx264",
    preset = "medium",      -- ultrafast, fast, medium, slow, veryslow
    crf = 23,               -- Quality: 0-51, lower = better

    -- Audio encoding
    audio_codec = "aac",
    audio_bitrate = "192k",

    -- Format
    pixel_format = "yuv420p",
    container = "mp4",
}
```

### Preset Tradeoffs

| Preset | Speed | File Size | Quality |
|--------|-------|-----------|---------|
| ultrafast | Very fast | Large | Lower |
| fast | Fast | Medium | Good |
| medium | Medium | Medium | Good |
| slow | Slow | Smaller | Better |
| veryslow | Very slow | Smallest | Best |

## CLI Integration

```bash
# In run.sh:
if [[ "$GENERATE_TRANCE_VIDEO" == "true" ]]; then
    log_info "Assembling trance video..."

    # Check dependencies
    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg not found. Install with: sudo apt install ffmpeg"
        exit 1
    fi

    luajit "$DIR/src/video-assembler.lua" "$DIR"
fi
```

```bash
# CLI flags:
--trance-video          # Enable video assembly
--video-preset P        # ffmpeg preset (default: medium)
--video-crf N           # Quality level (default: 23)
```

## Output

```
output/flopsopoly/
├── trance-track.wav               # Audio (from 13-002d)
├── trance-track-manifest.json     # Audio manifest
├── visuals/                       # Images (from 13-003c)
│   ├── final/
│   └── visual-manifest.json
├── concat.txt                     # From 13-004a
└── trance-video.mp4               # Final assembled video
```

## Testing

```bash
# Generate video
./run.sh --trance-video

# Verify output exists
ls -la output/flopsopoly/trance-video.mp4

# Check video properties
ffprobe output/flopsopoly/trance-video.mp4

# Play video (manual verification)
mpv output/flopsopoly/trance-video.mp4
# or
vlc output/flopsopoly/trance-video.mp4
```

### Automated Tests

```lua
-- Test: video file exists and has size
local video_path = "output/flopsopoly/trance-video.mp4"
assert(file_exists(video_path), "Video file not created")
assert(get_file_size(video_path) > 1000000, "Video file too small")  -- > 1MB

-- Test: duration matches audio
local audio_manifest = utils.read_json("output/flopsopoly/trance-track-manifest.json")
local video_duration = get_video_duration_ms(video_path)
local tolerance = 500  -- 500ms
assert(math.abs(video_duration - audio_manifest.total_duration_ms) < tolerance,
       "Duration mismatch")
```

## Performance Notes

Encoding is relatively fast:
- For 700 frames (still images): ~30-60 seconds with medium preset
- File size estimate: 50-200 MB depending on duration and quality

The bottleneck is frame count and duration, not encoding complexity (still images are easy to encode).

## Edge Cases

- **ffmpeg not installed**: Error with install instructions
- **Concat file has bad paths**: ffmpeg error — validate paths before assembly
- **Audio/video duration mismatch**: `-shortest` flag handles this, but warn
- **Disk space**: Estimate output size, warn if low space
- **Existing output file**: Overwritten (`-y` flag)

## Related Documents

- Issue 13-004: Assemble Video (parent)
- Issue 13-004a: Implement Manifest Parsing and Concat File Generation (provides concat.txt)
- Issue 13-004c: Implement Transition Effects (future enhancement)
- Issue 13-002d: Assemble Trance Track and Manifest (provides audio)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (provides images)

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Low-Medium (ffmpeg orchestration)
- **Dependencies**: 13-004a (concat file), ffmpeg (system)
- **Blocks**: None (final output)
