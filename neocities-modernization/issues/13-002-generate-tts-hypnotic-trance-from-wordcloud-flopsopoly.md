# Issue 13-002: Generate TTS Hypnotic Trance Track from Word-Cloud Flopsopoly

## Priority
High

## Current Behavior

The word cloud generator (`src/wordcloud-generator.lua`) produces a list of words with font sizes (1-7) based on frequency normalization. These words have cached embeddings in `word_embeddings.json`. However, this data is only used for visual HTML output — no audio representation exists.

## Intended Behavior

Generate an audio "hypnotic trance track" by:

1. **Building a flopsopoly** — A frequency-weighted word pool where each word appears N times (N = its font size, 1-7)
2. **Ordering via progressive centroid expansion** — Sequence the pool using a maximum-diversity algorithm driven by word embeddings
3. **Rendering to audio** — Pass each word through the TTS engine (from 13-001) in flopsopoly order
4. **Outputting a continuous audio track** — Concatenate word audio into a single hypnotic trance file

### Sub-Issues

This issue has been split into the following sub-issues:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| [13-002a](13-002a-build-frequency-weighted-word-pool.md) | Build frequency-weighted word pool | Open |
| [13-002b](13-002b-implement-centroid-expansion-ordering.md) | Implement centroid expansion ordering algorithm | Open |
| [13-002c](13-002c-generate-per-word-audio-cache.md) | Generate per-word audio cache via TTS | Open |
| [13-002d](13-002d-assemble-trance-track-and-manifest.md) | Assemble continuous trance track + manifest | Open |

**Dependency chain**: 13-002a → 13-002b → 13-002c → 13-002d

Note: 13-002a and 13-002b can be developed and tested before TTS engine (13-001) is complete.

### The Flopsopoly of Verbrases

A flopsopoly is a frequency-weighted, centroid-diversified word sequence:

**Step 1: Build the word pool**

For each word in the word cloud, add N copies where N equals its font size:

```
Word "silence" (size 7) → 7 instances: silence₁, silence₂, ..., silence₇
Word "window"  (size 2) → 2 instances: window₁, window₂
Word "fire"    (size 5) → 5 instances: fire₁, fire₂, ..., fire₅
...
```

Total pool size: sum of all word sizes across the word cloud (e.g., ~600-800 word tokens for 200 words with average size ~3.5).

**Step 2: Order via progressive centroid expansion**

The ordering algorithm is the inverse of typical centroid-attraction — it selects the **most distant** word from the running centroid at each step:

```
Algorithm: Progressive Centroid Expansion

1. Initialize: centroid = zero vector, sequence = []
2. For each remaining word in pool:
   a. Compute distance from each unselected word to current centroid
   b. Select the word MOST DISTANT from the centroid
   c. Append to sequence
   d. Update centroid: centroid = running average of all selected word embeddings
3. Return sequence
```

**Step 3: Self-regulating duplicates**

Since duplicate words share the same embedding, the algorithm naturally spaces them out:

- Selecting `silence₁` shifts the centroid toward "silence"
- This makes `silence₂` through `silence₇` temporarily CLOSER to the centroid
- Other words (whose embeddings differ) become more distant
- `silence₂` won't be selected again until the centroid has drifted far enough away that "silence" is once again the most distant word
- Higher-frequency words (more duplicates) create stronger centroid shifts, requiring more drift before re-selection
- The result: frequent words are distributed evenly throughout the sequence, creating a rhythm

**Step 4: TTS rendering**

Pass each word in flopsopoly order through the TTS engine:

```
silence → [audio] → fire → [audio] → memory → [audio] → ...
```

Concatenate all audio segments (with configurable inter-word silence) into a single track.

### Why This Creates a Hypnotic Experience

1. **Repetition with variation**: Frequent words recur but in different semantic neighborhoods
2. **Maximum diversity ordering**: Each word is as semantically different as possible from the recent context
3. **Self-regulating rhythm**: The centroid drift creates natural pacing — frequent words establish a heartbeat, rare words provide surprise
4. **No narrative structure**: Pure word-level semantics bypasses rational processing, engaging the subconscious
5. **Embedding-driven coherence**: Despite maximum diversity, all words come from the same poetic collection, creating a subliminal thematic unity

## Technical Design

### Flopsopoly Generation Algorithm

```lua
-- {{{ local function build_flopsopoly
-- Builds a frequency-weighted word pool from word cloud data
local function build_flopsopoly(word_cloud_data)
    local pool = {}
    for _, entry in ipairs(word_cloud_data) do
        -- Font size determines repetition count
        local copies = entry.font_size or 1
        for i = 1, copies do
            table.insert(pool, {
                word = entry.word,
                instance = i,
                embedding = entry.embedding,
                font_size = entry.font_size
            })
        end
    end
    return pool
end
-- }}}

-- {{{ local function order_by_centroid_expansion
-- Orders pool items by maximum distance from progressive centroid
-- Each selection shifts the centroid, naturally spacing duplicates
local function order_by_centroid_expansion(pool, word_embeddings)
    local dim = #word_embeddings[pool[1].word]
    local centroid = {}
    for d = 1, dim do centroid[d] = 0 end

    local selected = {}
    local remaining = {}
    for i, item in ipairs(pool) do remaining[i] = item end

    local centroid_count = 0

    while #remaining > 0 do
        -- Find most distant word from centroid
        local best_idx = 1
        local best_dist = -1

        for i, item in ipairs(remaining) do
            local emb = word_embeddings[item.word]
            if emb then
                local dist = 0
                if centroid_count == 0 then
                    -- First selection: pick arbitrarily (or by some seed)
                    dist = 1  -- All equally distant from zero centroid
                else
                    -- Cosine distance (1 - similarity) for maximum diversity
                    local dot, n1, n2 = 0, 0, 0
                    for d = 1, dim do
                        dot = dot + centroid[d] * emb[d]
                        n1 = n1 + centroid[d] * centroid[d]
                        n2 = n2 + emb[d] * emb[d]
                    end
                    local sim = dot / (math.sqrt(n1) * math.sqrt(n2) + 1e-10)
                    dist = 1 - sim
                end

                if dist > best_dist then
                    best_dist = dist
                    best_idx = i
                end
            end
        end

        -- Select and update centroid
        local selected_item = table.remove(remaining, best_idx)
        table.insert(selected, selected_item)

        local emb = word_embeddings[selected_item.word]
        if emb then
            centroid_count = centroid_count + 1
            for d = 1, dim do
                centroid[d] = centroid[d] + (emb[d] - centroid[d]) / centroid_count
            end
        end
    end

    return selected
end
-- }}}
```

### Audio Assembly

```lua
-- {{{ local function assemble_trance_track
-- Concatenates word audio files into a continuous trance track
local function assemble_trance_track(flopsopoly_sequence, audio_cache_dir, output_file, silence_ms)
    -- Generate audio for each unique word (cached)
    local unique_words = {}
    for _, item in ipairs(flopsopoly_sequence) do
        unique_words[item.word] = true
    end
    for word, _ in pairs(unique_words) do
        tts_engine.generate_word_audio(word, audio_cache_dir)
    end

    -- Concatenate in flopsopoly order with silence gaps
    local file_list = {}
    for _, item in ipairs(flopsopoly_sequence) do
        table.insert(file_list, audio_cache_dir .. "/" .. item.word .. ".wav")
        if silence_ms > 0 then
            table.insert(file_list, audio_cache_dir .. "/silence_" .. silence_ms .. "ms.wav")
        end
    end

    -- Use ffmpeg or sox for concatenation
    concatenate_audio(file_list, output_file)
end
-- }}}
```

### Configuration

```lua
-- In config.lua:
flopsopoly = {
    -- Audio settings
    inter_word_silence_ms = 500,    -- Silence between words (ms)
    output_format = "wav",           -- Output audio format
    output_file = "output/trance-track",  -- Output path (without extension)

    -- Flopsopoly settings
    seed_word = nil,                 -- First word (nil = deterministic from pool)
    use_font_size_for_copies = true, -- Use font_size as copy count (vs. raw frequency)
}
```

### Pipeline Integration

New pipeline stage (after word cloud generation):

```bash
# Stage N: Generate flopsopoly trance track
if [[ "$GENERATE_TRANCE" == "true" ]]; then
    log_info "🎵 Stage N: Generating hypnotic trance track..."
    luajit "$DIR/src/flopsopoly-generator.lua" "$DIR"
fi
```

## Output Structure

```
output/
├── trance-track.wav           # Full hypnotic trance audio
├── trance-track-manifest.json # Word sequence with timestamps
├── flopsopoly/
│   ├── sequence.json          # Ordered word list with metadata
│   └── audio-cache/           # Cached per-word audio files
│       ├── silence.wav
│       ├── memory.wav
│       ├── fire.wav
│       └── ...
```

The manifest file enables synchronization with visual content (13-003):

```json
{
    "sequence": [
        {"word": "silence", "instance": 1, "start_ms": 0, "end_ms": 620, "embedding_idx": 42},
        {"word": "fire", "instance": 1, "start_ms": 1120, "end_ms": 1580, "embedding_idx": 87},
        ...
    ],
    "total_duration_ms": 485000,
    "word_count": 742,
    "unique_words": 200
}
```

## Validation

- Pool size should equal sum of all word font sizes in the word cloud
- No two adjacent words in the flopsopoly should be the same word (unless pool is very small)
- Duplicate instances of a word should be roughly evenly spaced throughout the sequence
- Audio output should be a single continuous track with consistent inter-word spacing
- Manifest timestamps should be accurate (verify against audio file duration)

## Edge Cases

- **Word with no embedding**: Skip from pool, log warning
- **Single-word pool**: Output single word repeated (degenerate but valid)
- **TTS failure for a word**: Skip with silence gap, log error, continue
- **Very large pool** (>2000 tokens): May need progress display during centroid expansion

## Performance Notes

The centroid expansion algorithm is O(N²) where N = pool size. For a typical pool of ~700 tokens:
- 700² / 2 = ~245,000 distance computations
- Each is O(768) for embedding dimension
- Total: ~188M FLOPs ≈ <1 second on CPU

TTS generation dominates: ~0.5-2 seconds per word × 200 unique words = 100-400 seconds total.

## Original Request Context

> Okay now can we make an issue file in a new phase, a phase related to audio generation from similar/different embedding similarity matrix identity convolutional declarative iteration style programming? The first issue file should be about researching and implementing a TTS engine. The first todo item in that issue file should be to split the file into sub-issues, for research, design, and implementation. The next issue file should be about passing all the words from the word-cloud generator through a TTS, with the frequency of each word corresponding to the "size" of the word in the word cloud. If the base size is 1, and there's a word with size 7, then 7 instances of that word will be placed in the pool of words to iterate through with the TTS engine. These 7 instances will be pseudo-deterministically ordered in a big pool of words, a flopsopoly of verbrases if you will. This flopsopoly will be ordered in the way that makes the most sense, as determined by a progressively expanding centroid calculation that calculates the most distant word from among all of the remaining words. Since there are duplicate words by design, it will add one of the duplicates to the centroid which will then reduce the likelihood that the centroid (selecting the most distant word) will select that word again until the centralized cluster has been shifted enough that the already-selected-word is now the farthest. This should provide for an interesting hypnotic experience that can be matched to visuals created by a locally run stable diffusion model (IP address and port required) which creates images based on a flopsopoly of verbrases that correspond to the N most recent words that have been added to the flopsopoly. Note that N is taken from the forward and backwards directions, like a diameter is the same distance from the central point at both ends as the radius of a circle might be. The images will be created after the TTS hypnotic trance track has been generated, which means the image related functionality should be another issue. Please include this message in all of the issue files for further reference.

## Related Documents

- Issue 13-001: Research and Implement TTS Engine (dependency)
- Issue 13-003: Generate Stable Diffusion Visuals (downstream consumer of manifest)
- `src/wordcloud-generator.lua` — Word frequency and font size data
- `src/diversity-chaining.lua` — Reference implementation of centroid expansion
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — Word embeddings

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: High (novel algorithm + audio assembly pipeline)
- **Dependencies**: 13-001 (TTS engine)
- **Blocks**: 13-003 (needs manifest for synchronization)
