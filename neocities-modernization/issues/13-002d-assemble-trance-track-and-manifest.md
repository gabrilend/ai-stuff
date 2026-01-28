# Issue 13-002d: Assemble Trance Track and Manifest

## Priority
High (blocks 13-003, 13-004)

## Parent Issue
13-002: Generate TTS Hypnotic Trance Track from Word-Cloud Flopsopoly

## Current Behavior

After 13-002c completes:
- An ordered flopsopoly sequence exists (~700 word tokens)
- All unique words have cached audio files (~200 files)
- Duration information is available for each word

The audio files are separate — no continuous track exists, and there's no manifest for synchronization with visuals.

## Intended Behavior

Assemble the cached audio files into a **continuous trance track** following the flopsopoly sequence order, with configurable silence between words. Generate a **timing manifest** for downstream consumers (13-003 visuals, 13-004 video).

### Audio Assembly

```
[silence.wav] + [gap] + [fire.wav] + [gap] + [memory.wav] + [gap] + ...
     ↓              ↓           ↓              ↓
trance-track.wav (continuous audio file)
```

### Timing Manifest

```json
{
    "sequence": [
        {"word": "silence", "instance": 1, "start_ms": 0, "end_ms": 620, "embedding_idx": 42},
        {"word": "fire", "instance": 1, "start_ms": 1120, "end_ms": 1580, "embedding_idx": 87},
        {"word": "memory", "instance": 1, "start_ms": 2080, "end_ms": 2750, "embedding_idx": 15},
        ...
    ],
    "total_duration_ms": 485000,
    "word_count": 742,
    "unique_words": 200,
    "inter_word_silence_ms": 500,
    "created": "2026-01-28T12:00:00Z"
}
```

### Assembly Approach

**Option A: ffmpeg concat demuxer** (recommended)
```bash
# Generate concat list
echo "file 'silence.wav'" > concat.txt
echo "file 'silence_500ms.wav'" >> concat.txt
echo "file 'fire.wav'" >> concat.txt
echo "file 'silence_500ms.wav'" >> concat.txt
# ...

# Concatenate
ffmpeg -f concat -safe 0 -i concat.txt -c copy trance-track.wav
```

**Option B: sox**
```bash
sox silence.wav silence_500ms.wav fire.wav silence_500ms.wav ... trance-track.wav
```

### Silence Generation

Pre-generate silence files for configurable gap durations:
```bash
# Generate 500ms silence
ffmpeg -f lavfi -i anullsrc=r=22050:cl=mono -t 0.5 silence_500ms.wav
```

Or use sox:
```bash
sox -n -r 22050 -c 1 silence_500ms.wav trim 0.0 0.5
```

## Technical Design

```lua
-- {{{ local function assemble_trance_track
-- Concatenates word audio files into a continuous trance track
local function assemble_trance_track(sequence, audio_cache_dir, durations, config)
    local silence_ms = config.inter_word_silence_ms or 500
    local output_file = config.output_file or "output/flopsopoly/trance-track.wav"

    -- Generate silence file if needed
    local silence_file = audio_cache_dir .. "/silence_" .. silence_ms .. "ms.wav"
    if not file_exists(silence_file) then
        generate_silence_file(silence_file, silence_ms)
    end

    -- Build concat list
    local concat_list = {}
    local manifest_entries = {}
    local current_ms = 0

    for i, item in ipairs(sequence) do
        local word_file = audio_cache_dir .. "/" .. item.word .. ".wav"
        local duration = durations[item.word]

        -- Add word to concat list
        table.insert(concat_list, word_file)

        -- Add manifest entry
        table.insert(manifest_entries, {
            word = item.word,
            instance = item.instance,
            start_ms = current_ms,
            end_ms = current_ms + duration,
            embedding_idx = item.embedding_idx,
            font_size = item.font_size
        })

        current_ms = current_ms + duration

        -- Add silence gap (except after last word)
        if i < #sequence then
            table.insert(concat_list, silence_file)
            current_ms = current_ms + silence_ms
        end
    end

    -- Write concat file for ffmpeg
    local concat_path = "output/flopsopoly/concat.txt"
    write_concat_file(concat_list, concat_path)

    -- Execute ffmpeg
    local cmd = string.format(
        'ffmpeg -y -f concat -safe 0 -i "%s" -c copy "%s"',
        concat_path, output_file
    )
    os.execute(cmd)

    -- Build and save manifest
    local manifest = {
        sequence = manifest_entries,
        total_duration_ms = current_ms,
        word_count = #sequence,
        unique_words = count_unique_words(sequence),
        inter_word_silence_ms = silence_ms,
        created = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    return manifest
end
-- }}}
```

## Suggested Implementation Steps

1. **Generate silence files** — Pre-generate common durations (250, 500, 750, 1000 ms)
2. **Build concat list** — Interleave word files with silence
3. **Calculate timestamps** — Track cumulative time for manifest
4. **Write concat file** — ffmpeg-compatible format
5. **Execute assembly** — Run ffmpeg or sox
6. **Build manifest** — Timestamp each word in sequence
7. **Save outputs**:
   - `output/flopsopoly/trance-track.wav` — Main audio file
   - `output/flopsopoly/trance-track-manifest.json` — Timing manifest
8. **Validate output** — Check duration matches expected

## Deliverables

- [ ] Function `assemble_trance_track(sequence, cache_dir, durations, config)` implemented
- [ ] Silence file generation for configurable durations
- [ ] ffmpeg concat file generation
- [ ] `output/flopsopoly/trance-track.wav` — Continuous audio track
- [ ] `output/flopsopoly/trance-track-manifest.json` — Timing manifest
- [ ] Duration validation: manifest total matches audio file length

## Configuration

```lua
-- In config.lua:
flopsopoly = {
    inter_word_silence_ms = 500,    -- Silence between words (ms)
    output_format = "wav",           -- Output audio format
    output_file = "output/flopsopoly/trance-track",  -- Path without extension

    -- Optional: variable silence based on semantic distance
    variable_silence = false,
    min_silence_ms = 200,
    max_silence_ms = 800,
}
```

### Future Enhancement: Variable Silence

Optionally vary silence duration based on semantic distance between adjacent words:
- Very similar words → shorter gap (quick transition)
- Very different words → longer gap (dramatic pause)

This is a post-MVP enhancement and should be a separate sub-issue if pursued.

## Output Structure

```
output/flopsopoly/
├── pool.json                      # From 13-002a
├── sequence.json                  # From 13-002b
├── word_durations.json            # From 13-002c
├── concat.txt                     # ffmpeg concat list
├── trance-track.wav               # Main output: continuous audio
└── trance-track-manifest.json     # Timing manifest for 13-003, 13-004
```

## Validation

```lua
-- Test: manifest duration matches audio file
local audio_duration_ms = get_audio_duration_ms("output/flopsopoly/trance-track.wav")
local manifest_duration_ms = manifest.total_duration_ms
local tolerance_ms = 100  -- Allow small ffmpeg rounding errors
assert(math.abs(audio_duration_ms - manifest_duration_ms) < tolerance_ms,
       "Duration mismatch: audio=" .. audio_duration_ms .. " manifest=" .. manifest_duration_ms)

-- Test: manifest sequence length matches pool size
assert(#manifest.sequence == #sequence, "Manifest sequence length mismatch")

-- Test: timestamps are monotonic
for i = 2, #manifest.sequence do
    assert(manifest.sequence[i].start_ms >= manifest.sequence[i-1].end_ms,
           "Non-monotonic timestamps at position " .. i)
end
```

## Edge Cases

- **ffmpeg not installed**: Error with install instructions
- **sox fallback**: If ffmpeg unavailable, try sox
- **Very long track** (>30 min): Warn about file size, estimate duration
- **Empty sequence**: Return empty manifest, no audio file

## Performance Notes

Assembly is fast — the bottleneck is TTS generation (13-002c):
- ffmpeg concat: ~1 second for 700 files
- Manifest generation: instant
- Total: <5 seconds after audio cache is populated

## Related Documents

- Issue 13-002: Generate TTS Hypnotic Trance Track (parent)
- Issue 13-002b: Implement Centroid Expansion Ordering (provides sequence)
- Issue 13-002c: Generate Per-Word Audio Cache (provides audio files + durations)
- Issue 13-003: Generate Stable Diffusion Visuals (consumes manifest)
- Issue 13-004: Assemble Video (consumes audio + manifest)

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (audio assembly + manifest generation)
- **Dependencies**: 13-002b (sequence), 13-002c (audio cache + durations)
- **Blocks**: 13-003, 13-004
