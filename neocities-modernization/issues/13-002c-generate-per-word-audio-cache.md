# Issue 13-002c: Generate Per-Word Audio Cache

## Priority
High (blocks 13-002d)

## Parent Issue
13-002: Generate TTS Hypnotic Trance Track from Word-Cloud Flopsopoly

## Current Behavior

After 13-001c (TTS implementation) and 13-002b (ordering) complete:
- A TTS engine is integrated and callable from Lua
- An ordered flopsopoly sequence exists (~700 word tokens)
- No audio files have been generated for the words

## Intended Behavior

Generate audio files for each **unique word** in the flopsopoly sequence using the TTS engine, storing them in a cache directory for reuse:

```
assets/audio-cache/
├── silence.wav      # One file per unique word
├── memory.wav
├── fire.wav
├── window.wav
├── night.wav
├── dream.wav
└── ...              # ~200 unique words
```

### Why Cache Unique Words Only

The flopsopoly sequence contains ~700 word tokens, but only ~200 unique words. Since `silence_1` through `silence_7` all use the same audio file, we:
1. Generate audio for each unique word once
2. Reference the cached file for all instances in the sequence
3. Save ~71% of TTS processing time

### Audio Generation Process

```lua
-- For each unique word in the sequence:
for word, _ in pairs(unique_words) do
    local audio_path = cache_dir .. "/" .. word .. ".wav"
    if not file_exists(audio_path) then
        tts_engine.generate_word_audio(word, audio_path)
    end
end
```

### Duration Extraction

After generating each word's audio, extract and store its duration for manifest creation:

```lua
-- Build duration map for manifest
local durations = {}
for word, _ in pairs(unique_words) do
    local audio_path = cache_dir .. "/" .. word .. ".wav"
    durations[word] = tts_engine.get_word_duration_ms(audio_path)
end
```

## Suggested Implementation Steps

1. **Extract unique words from sequence** — Build set of unique words
2. **Check cache status** — Identify which words already have cached audio
3. **Generate missing audio** — Call TTS engine for uncached words
4. **Extract durations** — Use ffprobe or sox to get ms duration per file
5. **Build duration map** — `{word: duration_ms}` for manifest generation
6. **Report statistics** — Words generated, cache hits, total time
7. **Save duration map** — `output/flopsopoly/word_durations.json`

### Progress Display

```
Generating word audio: 50/200 (25%) - cache hits: 30 - elapsed: 45s
```

## Deliverables

- [ ] Function `generate_audio_cache(sequence, cache_dir)` implemented
- [ ] Cache directory created: `assets/audio-cache/`
- [ ] All unique words have corresponding `.wav` files
- [ ] Duration map generated: `{word: duration_ms}`
- [ ] Progress display during generation
- [ ] Statistics: total words, cache hits, generation time
- [ ] `output/flopsopoly/word_durations.json` saved

## Configuration

```lua
-- In config.lua:
tts = {
    cache_dir = "assets/audio-cache",
    use_cache = true,
    -- ... other TTS settings from 13-001c
}

flopsopoly = {
    regenerate_audio = false,  -- Force regeneration even if cached
}
```

## Edge Cases

- **TTS failure for a word**: Log error, skip word, continue (track failures)
- **Cache directory doesn't exist**: Create it
- **Existing cache with different TTS settings**: Consider cache invalidation strategy
- **Word with special characters**: Sanitize filename (or hash)
- **Very long word**: TTS should handle, but verify

### Filename Sanitization

Words may contain characters unsafe for filenames:
```lua
local function sanitize_filename(word)
    -- Replace unsafe characters with underscore
    return word:gsub("[^%w%-_]", "_")
end
```

Or use a hash-based approach:
```lua
local function word_to_filename(word)
    return md5(word) .. ".wav"  -- Consistent, safe, but not human-readable
end
```

## Testing

```lua
-- Test: all unique words have audio files
for word, _ in pairs(unique_words) do
    local path = cache_dir .. "/" .. word .. ".wav"
    assert(file_exists(path), "Missing audio for: " .. word)
end

-- Test: all durations are positive
for word, duration in pairs(durations) do
    assert(duration > 0, "Zero/negative duration for: " .. word)
end

-- Test: cache hits on second run
local stats1 = generate_audio_cache(sequence, cache_dir)
local stats2 = generate_audio_cache(sequence, cache_dir)
assert(stats2.cache_hits == stats2.total, "Cache not working")
```

## Performance Notes

TTS generation dominates runtime:
- Estimated: ~0.5-2 seconds per word (depends on engine)
- For 200 unique words: 100-400 seconds (1.5-6.5 minutes)
- With caching, subsequent runs are instant

## Related Documents

- Issue 13-002: Generate TTS Hypnotic Trance Track (parent)
- Issue 13-001c: Implement TTS Integration (provides TTS engine)
- Issue 13-002b: Implement Centroid Expansion Ordering (provides sequence)
- Issue 13-002d: Assemble Trance Track + Manifest (uses cache and durations)
- `libs/tts-engine.lua` — TTS wrapper module

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (TTS integration + caching)
- **Dependencies**: 13-001c (TTS engine), 13-002b (sequence)
- **Blocks**: 13-002d
