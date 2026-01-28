# Issue 13-001b: Design TTS Integration Architecture

## Priority
High (blocks 13-001c)

## Parent Issue
13-001: Research and Implement TTS Engine

## Current Behavior

After 13-001a completes, a TTS engine will be selected but not yet integrated. The project has no defined interface for text-to-speech, no caching strategy for generated audio, and no configuration schema for TTS parameters.

## Intended Behavior

Define the complete architecture for TTS integration before implementation begins:
- Interface between Lua pipeline and TTS engine
- Audio file naming and caching strategy
- Configuration schema in `config.lua`
- Error handling patterns
- Pipeline integration points

### Architecture Questions to Answer

1. **Invocation model**:
   - CLI binary (e.g., `piper --output-file word.wav "silence"`)?
   - HTTP API (like Ollama)?
   - Decision depends on 13-001a findings

2. **Caching strategy**:
   - Pre-generate all word audio files on first run?
   - Generate on-demand during flopsopoly assembly?
   - Cache location: `assets/audio-cache/` or model-specific subdirectory?

3. **Audio format**:
   - WAV (lossless, easy to concatenate) vs. MP3 (compressed)?
   - Sample rate: 22050 Hz? 44100 Hz?
   - Mono vs. stereo?

4. **Silence/spacing**:
   - How much silence between words? Configurable?
   - Pre-generate silence files of various durations?

5. **Configuration location**:
   - New `tts` section in `config.lua`
   - Voice parameters (speed, pitch, tone)
   - Engine-specific settings

6. **Error handling**:
   - What if TTS fails for a specific word?
   - Retry logic? Skip with warning? Error out?

### Proposed Interface

```lua
-- libs/tts-engine.lua

-- {{{ tts_engine.init
-- Initialize the TTS engine with configuration
-- @param config: table with engine settings
-- @return boolean success
local function init(config)
end
-- }}}

-- {{{ tts_engine.generate_word_audio
-- Generate audio file for a single word
-- @param word: string to synthesize
-- @param output_path: path to save audio file
-- @return boolean success, string error_message
local function generate_word_audio(word, output_path)
end
-- }}}

-- {{{ tts_engine.generate_cached
-- Generate audio for word, using cache if available
-- @param word: string to synthesize
-- @param cache_dir: directory for cached audio files
-- @return string audio_path, boolean was_cached
local function generate_cached(word, cache_dir)
end
-- }}}

-- {{{ tts_engine.get_word_duration_ms
-- Get duration of word audio in milliseconds
-- @param audio_path: path to audio file
-- @return number duration_ms
local function get_word_duration_ms(audio_path)
end
-- }}}
```

### Proposed Configuration Schema

```lua
-- In config.lua:
tts = {
    -- Engine selection (based on 13-001a recommendation)
    engine = "piper",  -- or "coqui", "espeak", etc.

    -- Voice settings
    voice = "en_US-lessac-medium",  -- Engine-specific voice ID
    speed = 1.0,    -- Speech rate multiplier
    pitch = 1.0,    -- Pitch adjustment (if supported)

    -- Audio output settings
    format = "wav",         -- Output format
    sample_rate = 22050,    -- Sample rate in Hz
    channels = 1,           -- Mono

    -- Caching
    cache_dir = "assets/audio-cache",
    use_cache = true,

    -- Engine-specific paths (if needed)
    binary_path = nil,      -- Path to TTS binary (nil = use PATH)
    model_path = nil,       -- Path to voice model (engine-specific)

    -- Error handling
    retry_on_failure = true,
    max_retries = 2,
}
```

## Suggested Implementation Steps

1. **Review 13-001a findings** — Understand the chosen engine's CLI/API interface
2. **Draft interface specification** — Define the Lua function signatures
3. **Design caching strategy** — Decide on cache location, naming, and invalidation
4. **Write configuration schema** — Add `tts` section to `config.lua`
5. **Document error handling patterns** — Define behavior for edge cases
6. **Create architecture diagram** — Show data flow from word → audio file
7. **Review with 13-002 requirements** — Ensure interface meets flopsopoly needs

## Deliverables

- [ ] `libs/tts-engine.lua` interface specification (function signatures, no implementation)
- [ ] Configuration schema added to `config.lua` (commented out, ready for 13-001c)
- [ ] Caching strategy documentation
- [ ] Error handling patterns documented
- [ ] Data flow diagram (word → TTS → cache → output)

## Related Documents

- Issue 13-001: Research and Implement TTS Engine (parent)
- Issue 13-001a: Research TTS Options (provides engine selection)
- Issue 13-001c: Implement TTS Integration (next step)
- Issue 13-002: Generate TTS Hypnotic Trance Track (downstream consumer)
- `libs/ollama-config.lua` — Reference for local service integration pattern
- `libs/config-loader.lua` — Configuration loading pattern

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (architecture design)
- **Dependencies**: 13-001a (engine selection)
- **Blocks**: 13-001c
