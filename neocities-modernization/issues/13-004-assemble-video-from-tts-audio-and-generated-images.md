# Issue 13-004: Assemble Video from TTS Audio and Generated Images

## Priority
Medium

## Current Behavior

Issues 13-002 and 13-003 produce separate outputs:
- **Audio**: A continuous TTS hypnotic trance track (`output/trance-track.wav`) with a word-timestamped manifest
- **Images**: A sequence of stable diffusion frames (`output/flopsopoly/visuals/final/frame_NNNNNN.png`) with a visual manifest

These outputs exist independently. There is no combined audio-visual experience — the user must manually synchronize them or view/listen separately.

## Intended Behavior

Assemble a **video file** that combines the TTS audio track with the generated image sequence, creating a unified hypnotic audio-visual experience.

### Sub-Issues

This issue has been split into the following sub-issues:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| [13-004a](13-004a-implement-manifest-parsing-and-concat-file-generation.md) | Implement manifest parsing + concat file generation | Open |
| [13-004b](13-004b-implement-ffmpeg-video-assembly.md) | Implement ffmpeg video assembly (MVP sharp cuts) | Open |
| [13-004c](13-004c-implement-transition-effects.md) | Implement transition effects (post-MVP) | Open (blocked) |

**Dependency chain**: 13-004a → 13-004b → 13-004c (optional)

Note: 13-004c (transitions) is blocked by 13-004b MVP completion. Architecture should anticipate transitions, but implementation is deferred.

### MVP: Sharp Cuts

For the initial implementation, use **sharp cuts** between images:
- Each image displays for the duration of its corresponding word(s) in the audio track
- Transitions are instant (no blending, no fade)
- The audio track plays continuously underneath

```
Timeline:

Audio:  |--silence--|--fire--|--memory--|--ocean--|--dream--|--night--|
Video:  | frame_001 |frame_002|frame_003|frame_004|frame_005|frame_006|
        ↑ sharp cut ↑        ↑         ↑         ↑         ↑
```

### Future: Playful Blending

After the MVP, add optional transition effects:
- **Crossfade**: Smooth blend between adjacent frames (configurable duration)
- **Dissolve**: Fade through black between frames
- **Morph**: Interpolate between frames using stable diffusion img2img
- **Ken Burns**: Slow zoom/pan on each frame before cutting

These are non-MVP enhancements and should be tracked in a separate sub-issue if desired.

## Technical Design

### Video Assembly with ffmpeg

The primary tool for video assembly is `ffmpeg`, which is standard on Linux and handles:
- Image sequence → video conversion
- Audio track overlay
- Frame timing from manifest data

### Approach 1: Uniform Frame Duration

If all words have roughly equal audio duration, use a fixed framerate:

```bash
# Simple: all frames equal duration
ffmpeg -framerate 2 -i output/flopsopoly/visuals/final/frame_%06d.png \
       -i output/trance-track.wav \
       -c:v libx264 -pix_fmt yuv420p \
       -c:a aac -shortest \
       output/flopsopoly/trance-video.mp4
```

### Approach 2: Variable Frame Duration (from manifest)

Use the audio manifest timestamps to create a concat demuxer file with per-frame durations:

```lua
-- {{{ local function generate_ffmpeg_concat_file
-- Creates an ffmpeg concat demuxer file with per-frame durations from manifest
local function generate_ffmpeg_concat_file(audio_manifest, visuals_dir, output_path)
    local concat_parts = {}

    for i, entry in ipairs(audio_manifest.sequence) do
        local frame_file = string.format("%s/frame_%06d.png", visuals_dir, i)
        local duration_s = (entry.end_ms - entry.start_ms) / 1000.0

        -- Include inter-word silence in frame duration
        local next_start = audio_manifest.sequence[i + 1]
            and audio_manifest.sequence[i + 1].start_ms
            or entry.end_ms
        local total_duration_s = (next_start - entry.start_ms) / 1000.0

        table.insert(concat_parts, string.format("file '%s'", frame_file))
        table.insert(concat_parts, string.format("duration %.3f", total_duration_s))
    end

    -- ffmpeg concat requires the last file listed twice (quirk)
    local last_frame = string.format("%s/frame_%06d.png",
        visuals_dir, #audio_manifest.sequence)
    table.insert(concat_parts, string.format("file '%s'", last_frame))

    utils.write_file(output_path, table.concat(concat_parts, "\n"))
end
-- }}}
```

Then assemble with:

```bash
# Variable duration: each frame matches its word's audio timing
ffmpeg -f concat -safe 0 -i output/flopsopoly/concat.txt \
       -i output/trance-track.wav \
       -c:v libx264 -pix_fmt yuv420p -vf "scale=1024:1024" \
       -c:a aac -b:a 192k \
       -shortest \
       output/flopsopoly/trance-video.mp4
```

### Pipeline Integration

```bash
# In run.sh:
# Stage N+1: Assemble trance video
if [[ "$GENERATE_TRANCE_VIDEO" == "true" ]]; then
    log_info "🎬 Stage N+1: Assembling trance video..."
    luajit "$DIR/src/video-assembler.lua" "$DIR"
fi
```

### Configuration

```lua
-- In config.lua:
trance_video = {
    output_file = "output/flopsopoly/trance-video.mp4",
    video_codec = "libx264",
    audio_codec = "aac",
    audio_bitrate = "192k",
    pixel_format = "yuv420p",
    resolution = "1024x1024",      -- Match stable diffusion output

    -- Transition settings (MVP: sharp only)
    transition = "sharp",           -- "sharp" (MVP), "crossfade", "dissolve"
    crossfade_duration_ms = 200,    -- For future crossfade mode

    -- Frame timing
    use_manifest_timing = true,     -- Use audio manifest for per-frame duration
    fallback_fps = 2,               -- Fallback FPS if manifest unavailable
}
```

### CLI Integration

```bash
# In run.sh:
--trance-video          # Enable video assembly
--video-transition T    # Transition type: "sharp" (default), "crossfade"
```

## Output Structure

```
output/flopsopoly/
├── trance-track.wav               # Audio (from 13-002)
├── trance-track-manifest.json     # Audio timestamps (from 13-002)
├── visuals/                       # Images (from 13-003)
│   ├── final/
│   │   └── frame_NNNNNN.png
│   └── visual-manifest.json
├── concat.txt                     # ffmpeg concat demuxer file (generated)
└── trance-video.mp4               # Final assembled video
```

## Validation

- Output video file should be a valid MP4 playable in standard video players
- Video duration should match audio duration (within 1 second)
- Each frame should display for the correct duration per the audio manifest
- Audio should be in sync with the corresponding visual frames
- Resolution should match the stable diffusion output (default 1024×1024)
- File size estimate: ~742 frames × 1024×1024 at libx264 ≈ 50-200 MB depending on duration

## Edge Cases

- **ffmpeg not installed**: Error immediately with install instructions
- **Mismatched frame count**: If fewer images than audio words, loop last image; if more, truncate
- **Audio manifest missing**: Fall back to uniform frame rate (fallback_fps)
- **Very long video** (>30 min): Warn about encoding time and file size
- **Missing frames**: Skip with black frame, log warning

## Dependencies

- **13-002**: Audio track and manifest (must be completed first)
- **13-003**: Image sequence and visual manifest (must be completed first)
- **ffmpeg**: System dependency (must be installed)

## Future Enhancements (Post-MVP)

These should be tracked as separate sub-issues when needed:

- **Crossfade transitions**: Smooth alpha blending between frames
- **Dissolve through black**: Fade out → black → fade in
- **Variable transition speed**: Faster transitions for semantically similar adjacent words, slower for distant ones
- **Subtitle overlay**: Display each word as text synchronized with the audio
- **Loop mode**: Seamless loop for continuous playback (match first/last frames)
- **Multiple resolutions**: Generate 720p, 1080p, 4K variants

## Original Request Context

> Okay now can we make an issue file in a new phase, a phase related to audio generation from similar/different embedding similarity matrix identity convolutional declarative iteration style programming? The first issue file should be about researching and implementing a TTS engine. The first todo item in that issue file should be to split the file into sub-issues, for research, design, and implementation. The next issue file should be about passing all the words from the word-cloud generator through a TTS, with the frequency of each word corresponding to the "size" of the word in the word cloud. If the base size is 1, and there's a word with size 7, then 7 instances of that word will be placed in the pool of words to iterate through with the TTS engine. These 7 instances will be pseudo-deterministically ordered in a big pool of words, a flopsopoly of verbrases if you will. This flopsopoly will be ordered in the way that makes the most sense, as determined by a progressively expanding centroid calculation that calculates the most distant word from among all of the remaining words. Since there are duplicate words by design, it will add one of the duplicates to the centroid which will then reduce the likelihood that the centroid (selecting the most distant word) will select that word again until the centralized cluster has been shifted enough that the already-selected-word is now the farthest. This should provide for an interesting hypnotic experience that can be matched to visuals created by a locally run stable diffusion model (IP address and port required) which creates images based on a flopsopoly of verbrases that correspond to the N most recent words that have been added to the flopsopoly. Note that N is taken from the forward and backwards directions, like a diameter is the same distance from the central point at both ends as the radius of a circle might be. The images will be created after the TTS hypnotic trance track has been generated, which means the image related functionality should be another issue. Please include this message in all of the issue files for further reference.

> also, unrelated but we should create another issue file to create a video with an audio track of the hypnotic TTS output and the visuals being the images that are created, maybe with some playful blending between them but for the MVP it can have sharp-cuts between images for each frame.

## Related Documents

- Issue 13-001: Research and Implement TTS Engine (upstream)
- Issue 13-002: Generate TTS Hypnotic Trance Track (provides audio + manifest)
- Issue 13-003: Generate Stable Diffusion Visuals (provides image sequence + manifest)
- `src/diversity-chaining.lua` — Reference for manifest-driven pipeline patterns

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (ffmpeg orchestration + manifest parsing)
- **Dependencies**: 13-002 (audio), 13-003 (images), ffmpeg (system)
