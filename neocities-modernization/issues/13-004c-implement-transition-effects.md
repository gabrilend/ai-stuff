# Issue 13-004c: Implement Transition Effects (Post-MVP)

## Priority
Low (enhancement, blocked by MVP)

## Parent Issue
13-004: Assemble Video from TTS Audio and Generated Images

## Blocked By
13-004b: Implement ffmpeg Video Assembly (MVP Sharp Cuts)

**Note**: This issue should only be started after 13-004b (MVP with sharp cuts) is complete and validated. The architecture should be designed with transitions in mind, but implementation is deferred.

## Current Behavior

After 13-004b completes, video assembly works with **sharp cuts** — each frame displays for its duration, then instantly switches to the next frame. This is functional but visually abrupt.

## Intended Behavior

Add optional **transition effects** between frames:
- **Crossfade**: Smooth alpha blend between adjacent frames
- **Dissolve**: Fade out → black → fade in
- **Variable timing**: Longer transitions for semantically distant words

### Transition Types

#### 1. Crossfade

Smooth blend between frame A and frame B over a configurable duration:

```
Time:    |--A 100%--|--blend--|--B 100%--|
Alpha A: 1.0 -----> 0.5 ----> 0.0
Alpha B: 0.0 -----> 0.5 ----> 1.0
```

**ffmpeg approach:**
```bash
# Using xfade filter
ffmpeg -i frame_A.png -i frame_B.png \
    -filter_complex "xfade=transition=fade:duration=0.2:offset=0.8" \
    output.mp4
```

For full sequence, this becomes complex — may need to generate intermediate blend frames or use a more sophisticated approach.

#### 2. Dissolve Through Black

Frame A fades to black, then frame B fades in from black:

```
Time:    |--A 100%--|--fade out--|--black--|--fade in--|--B 100%--|
```

**ffmpeg approach:**
```bash
# Fade out A, then fade in B
ffmpeg -i frame_A.png -vf "fade=t=out:st=0.8:d=0.2" -t 1 a_fadeout.mp4
ffmpeg -i frame_B.png -vf "fade=t=in:st=0:d=0.2" -t 1 b_fadein.mp4
```

#### 3. Variable Timing Based on Semantic Distance

Adjust transition duration based on how semantically different adjacent frames are:
- Very similar words → quick transition (100ms)
- Very different words → slow transition (500ms)

```lua
local function calculate_transition_duration(frame_a, frame_b, config)
    local similarity = cosine_similarity(
        frame_a.center_embedding,
        frame_b.center_embedding
    )

    -- Map similarity to duration
    -- similarity 1.0 (identical) → min_duration
    -- similarity 0.0 (orthogonal) → max_duration
    local min_ms = config.min_transition_ms or 100
    local max_ms = config.max_transition_ms or 500

    return min_ms + (1 - similarity) * (max_ms - min_ms)
end
```

## Technical Design

### Configuration

```lua
-- In config.lua:
trance_video = {
    -- ... base settings from 13-004b ...

    -- Transition settings
    transition = "sharp",           -- "sharp" (MVP), "crossfade", "dissolve"
    transition_duration_ms = 200,   -- Fixed duration for crossfade/dissolve

    -- Variable transition (optional)
    variable_transitions = false,
    min_transition_ms = 100,
    max_transition_ms = 500,
}
```

### Implementation Approaches

#### Approach A: Pre-render Blend Frames

Generate intermediate frames for transitions before assembly:

```lua
-- {{{ local function generate_blend_frames
local function generate_blend_frames(frame_a_path, frame_b_path, output_dir, num_steps)
    -- Use ImageMagick to generate blend sequence
    for i = 1, num_steps do
        local alpha = i / (num_steps + 1)
        local output_path = string.format("%s/blend_%03d.png", output_dir, i)

        local cmd = string.format(
            'convert "%s" "%s" -compose blend -define compose:args=%d,%d -composite "%s"',
            frame_a_path, frame_b_path,
            math.floor((1 - alpha) * 100), math.floor(alpha * 100),
            output_path
        )
        os.execute(cmd)
    end
end
-- }}}
```

Update concat.txt to include blend frames with short durations.

#### Approach B: ffmpeg Filter Complex

Use ffmpeg's xfade filter for transitions (complex for long sequences):

```bash
# For 3 frames with crossfade:
ffmpeg -loop 1 -t 1 -i frame1.png \
       -loop 1 -t 1 -i frame2.png \
       -loop 1 -t 1 -i frame3.png \
       -filter_complex \
       "[0][1]xfade=transition=fade:duration=0.2:offset=0.8[v1]; \
        [v1][2]xfade=transition=fade:duration=0.2:offset=1.6[v2]" \
       -map "[v2]" output.mp4
```

This approach becomes unwieldy for hundreds of frames.

#### Approach C: Video Editing Library

Use a video editing library (e.g., MoviePy for Python) that handles transitions natively:

```python
from moviepy.editor import *

clips = [ImageClip(f).set_duration(d) for f, d in frames_with_durations]
video = concatenate_videoclips(clips, method="compose", transition=crossfadein(0.2))
video.write_videofile("output.mp4")
```

This requires a Python dependency but may be cleaner for complex transitions.

### Recommended Approach

**Approach A (pre-render blend frames)** is recommended because:
1. Stays within the Lua + shell ecosystem
2. Works with existing ffmpeg concat workflow
3. Enables variable transition durations
4. ImageMagick is likely already installed

## Suggested Implementation Steps

1. **Verify 13-004b MVP works** — Don't break sharp cuts
2. **Add transition config** — New settings in `config.lua`
3. **Implement blend frame generation** — ImageMagick composite
4. **Update concat file generation** — Include blend frames with durations
5. **Implement variable timing** — Calculate from semantic distance
6. **Add CLI flags** — `--video-transition`, `--transition-duration`
7. **Test all transition types** — Verify smooth playback
8. **Benchmark** — Measure additional processing time

## Deliverables

- [ ] Transition configuration schema in `config.lua`
- [ ] Crossfade implementation (pre-rendered blend frames)
- [ ] Dissolve implementation (fade through black)
- [ ] Variable transition timing based on semantic distance
- [ ] Updated concat file generation for transitions
- [ ] CLI flags: `--video-transition`, `--transition-duration`
- [ ] Documentation of transition types and tradeoffs

## Testing

```bash
# Test crossfade
./run.sh --trance-video --video-transition crossfade --transition-duration 200

# Test dissolve
./run.sh --trance-video --video-transition dissolve

# Test variable timing
./run.sh --trance-video --video-transition crossfade --variable-transitions

# Compare file sizes
ls -la output/flopsopoly/trance-video-*.mp4
```

## Performance Notes

Transitions add processing time:
- Pre-rendered blend frames: +2-5 frames per transition × N transitions
- For 700 transitions with 5 blend frames each: 3,500 additional frames
- ImageMagick blend: ~0.1-0.5s per frame
- Total additional time: 6-30 minutes

Consider:
- Reducing blend frame count (3 instead of 5)
- Parallel blend generation
- Caching blend frames

## Edge Cases

- **ImageMagick not installed**: Error with install instructions, fallback to sharp
- **Variable transitions with no embeddings**: Fallback to fixed duration
- **Very short frame duration**: Skip transition if frame < transition duration
- **First/last frame**: No transition before first or after last

## Future Enhancements

These could be additional sub-issues if needed:
- **Ken Burns effect**: Slow zoom/pan on each frame
- **Morph transitions**: Use img2img to generate intermediate frames
- **Audio-reactive transitions**: Sync transition timing to audio features
- **Subtitle overlay**: Display word text synchronized with audio

## Related Documents

- Issue 13-004: Assemble Video (parent)
- Issue 13-004b: Implement ffmpeg Video Assembly (MVP, must complete first)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (provides frames)
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — For semantic distance

## Metadata

- **Status**: Open (blocked by 13-004b)
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium-High (video processing + semantic integration)
- **Dependencies**: 13-004b (MVP must work first)
- **Blocks**: None (enhancement)
