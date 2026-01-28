# Issue 13-004a: Implement Manifest Parsing and Concat File Generation

## Priority
High (blocks 13-004b)

## Parent Issue
13-004: Assemble Video from TTS Audio and Generated Images

## Current Behavior

After 13-002d and 13-003c complete:
- Audio manifest exists: `output/flopsopoly/trance-track-manifest.json`
- Visual manifest exists: `output/flopsopoly/visuals/visual-manifest.json`
- Images exist: `output/flopsopoly/visuals/final/frame_NNNNNN.png`
- Audio track exists: `output/flopsopoly/trance-track.wav`

No logic exists to:
1. Parse and correlate the manifests
2. Generate the ffmpeg concat demuxer file with per-frame durations

## Intended Behavior

Implement manifest parsing and ffmpeg concat file generation for video assembly:

1. **Load audio manifest** — Get word timestamps (start_ms, end_ms)
2. **Load visual manifest** — Get frame-to-position mapping
3. **Correlate frames to audio timing** — Calculate duration for each frame
4. **Generate concat demuxer file** — ffmpeg-compatible format with per-frame durations

### Concat Demuxer Format

ffmpeg's concat demuxer reads a text file listing files and durations:

```
file '/path/to/frame_000001.png'
duration 1.120
file '/path/to/frame_000002.png'
duration 0.960
file '/path/to/frame_000003.png'
duration 1.080
...
file '/path/to/frame_000700.png'
```

Note: The last file must be listed twice (ffmpeg quirk) or it will be cut short.

### Duration Calculation

Each frame's duration depends on the frame_interval setting:

**frame_interval = 1** (one image per word):
```
frame_000025.duration = word_25.end_ms - word_25.start_ms + inter_word_silence
```

**frame_interval = 3** (one image every 3 words):
```
frame_000025.duration = word_27.end_ms - word_25.start_ms
                      = sum of durations for words 25, 26, 27 + silences
```

### Manifest Correlation

The visual manifest tracks which positions have frames:
```json
{"position": 1, "audio_start_ms": 0, "audio_end_ms": 620}
{"position": 4, "audio_start_ms": 3240, "audio_end_ms": 3890}  // frame_interval=3
```

Calculate frame duration as the time until the next frame's audio_start_ms.

## Technical Design

```lua
-- {{{ local function load_manifests
local function load_manifests(output_dir)
    local audio_manifest = utils.read_json(output_dir .. "/trance-track-manifest.json")
    local visual_manifest = utils.read_json(output_dir .. "/visuals/visual-manifest.json")

    return audio_manifest, visual_manifest
end
-- }}}

-- {{{ local function calculate_frame_durations
-- Calculates duration for each frame based on audio timing
local function calculate_frame_durations(audio_manifest, visual_manifest)
    local frames = visual_manifest.frames
    local durations = {}

    for i, frame in ipairs(frames) do
        local duration_ms

        if i < #frames then
            -- Duration = time until next frame starts
            duration_ms = frames[i + 1].audio_start_ms - frame.audio_start_ms
        else
            -- Last frame: duration = remaining audio time
            duration_ms = audio_manifest.total_duration_ms - frame.audio_start_ms
        end

        durations[i] = {
            frame = frame,
            duration_ms = duration_ms,
            duration_s = duration_ms / 1000.0
        }
    end

    return durations
end
-- }}}

-- {{{ local function generate_concat_file
-- Generates ffmpeg concat demuxer file
local function generate_concat_file(frame_durations, visuals_dir, output_path)
    local lines = {}

    for i, entry in ipairs(frame_durations) do
        local frame_path = visuals_dir .. "/final/" .. entry.frame.image_file

        -- Verify frame exists
        if not file_exists(frame_path) then
            io.stderr:write(string.format("Warning: Missing frame: %s\n", frame_path))
            -- Use black frame or skip?
        end

        table.insert(lines, string.format("file '%s'", frame_path))
        table.insert(lines, string.format("duration %.3f", entry.duration_s))
    end

    -- ffmpeg quirk: last file must be listed again without duration
    if #frame_durations > 0 then
        local last_frame = frame_durations[#frame_durations]
        local last_path = visuals_dir .. "/final/" .. last_frame.frame.image_file
        table.insert(lines, string.format("file '%s'", last_path))
    end

    utils.write_file(output_path, table.concat(lines, "\n"))

    return #frame_durations
end
-- }}}
```

### Validation

```lua
-- {{{ local function validate_manifests
local function validate_manifests(audio_manifest, visual_manifest)
    local errors = {}

    -- Check audio manifest has sequence
    if not audio_manifest.sequence or #audio_manifest.sequence == 0 then
        table.insert(errors, "Audio manifest has no sequence")
    end

    -- Check visual manifest has frames
    if not visual_manifest.frames or #visual_manifest.frames == 0 then
        table.insert(errors, "Visual manifest has no frames")
    end

    -- Check timestamps are monotonic
    local prev_start = -1
    for i, frame in ipairs(visual_manifest.frames or {}) do
        if frame.audio_start_ms <= prev_start then
            table.insert(errors, string.format(
                "Non-monotonic timestamp at frame %d: %d <= %d",
                i, frame.audio_start_ms, prev_start
            ))
        end
        prev_start = frame.audio_start_ms
    end

    -- Check total duration matches
    if audio_manifest.total_duration_ms then
        local last_frame = visual_manifest.frames[#visual_manifest.frames]
        if last_frame and last_frame.audio_end_ms > audio_manifest.total_duration_ms then
            table.insert(errors, string.format(
                "Visual manifest extends beyond audio: %d > %d",
                last_frame.audio_end_ms, audio_manifest.total_duration_ms
            ))
        end
    end

    return #errors == 0, errors
end
-- }}}
```

## Suggested Implementation Steps

1. **Implement `load_manifests(output_dir)`** — Load both JSON manifests
2. **Implement `validate_manifests(audio, visual)`** — Check consistency
3. **Implement `calculate_frame_durations(audio, visual)`** — Compute per-frame timing
4. **Implement `generate_concat_file(durations, dir, path)`** — Write ffmpeg format
5. **Add frame existence check** — Warn or error on missing frames
6. **Create test cases** — Various frame_interval scenarios
7. **Output statistics** — Total frames, total duration, min/max frame duration

## Deliverables

- [ ] `libs/video-manifest-parser.lua` — Manifest parsing module
- [ ] `load_manifests(output_dir)` function
- [ ] `validate_manifests(audio, visual)` function
- [ ] `calculate_frame_durations(audio, visual)` function
- [ ] `generate_concat_file(durations, dir, path)` function
- [ ] `output/flopsopoly/concat.txt` — Generated concat demuxer file
- [ ] Statistics output: frame count, duration range

## Output

**concat.txt example:**
```
file '/path/to/output/flopsopoly/visuals/final/frame_000001.png'
duration 1.120
file '/path/to/output/flopsopoly/visuals/final/frame_000002.png'
duration 0.960
file '/path/to/output/flopsopoly/visuals/final/frame_000003.png'
duration 1.080
...
file '/path/to/output/flopsopoly/visuals/final/frame_000700.png'
duration 0.840
file '/path/to/output/flopsopoly/visuals/final/frame_000700.png'
```

## Testing

```lua
-- Test: duration calculation
local audio = {total_duration_ms = 10000, sequence = {...}}
local visual = {frames = {
    {audio_start_ms = 0, audio_end_ms = 1000, image_file = "f1.png"},
    {audio_start_ms = 1500, audio_end_ms = 2500, image_file = "f2.png"},
    {audio_start_ms = 3000, audio_end_ms = 4000, image_file = "f3.png"},
}}

local durations = calculate_frame_durations(audio, visual)

assert(durations[1].duration_ms == 1500, "Frame 1 duration wrong")  -- 0 to 1500
assert(durations[2].duration_ms == 1500, "Frame 2 duration wrong")  -- 1500 to 3000
assert(durations[3].duration_ms == 7000, "Frame 3 duration wrong")  -- 3000 to 10000

-- Test: concat file format
local concat_content = utils.read_file("output/flopsopoly/concat.txt")
assert(concat_content:find("file '.*/frame_000001.png'"), "Missing first frame")
assert(concat_content:find("duration %d+%.%d+"), "Missing duration line")
```

## Edge Cases

- **Mismatched frame counts**: Visual has fewer frames than audio words (expected with frame_interval > 1)
- **Missing frames**: Warn, optionally use black placeholder
- **Zero duration**: Minimum 0.001s (1ms) to avoid ffmpeg errors
- **Very long duration**: Warn if single frame > 10s (possible manifest error)

## Related Documents

- Issue 13-004: Assemble Video (parent)
- Issue 13-004b: Implement ffmpeg Video Assembly (uses concat file)
- Issue 13-002d: Assemble Trance Track and Manifest (audio manifest source)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (visual manifest source)

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Low-Medium (manifest parsing + file generation)
- **Dependencies**: 13-002d (audio manifest), 13-003c (visual manifest)
- **Blocks**: 13-004b
