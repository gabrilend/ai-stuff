# Issue 13-001c: Implement TTS Integration

## Priority
High (blocks 13-002c)

## Parent Issue
13-001: Research and Implement TTS Engine

## Current Behavior

After 13-001a (research) and 13-001b (design) complete:
- A TTS engine has been selected and evaluated
- The integration architecture has been designed
- The Lua interface has been specified
- The configuration schema has been drafted

No actual implementation exists yet.

## Intended Behavior

Implement the TTS integration according to the architecture defined in 13-001b:
- Install and configure the chosen TTS engine
- Create `libs/tts-engine.lua` with full implementation
- Enable the configuration in `config.lua`
- Add TTS validation to pipeline startup
- Test with sample words from the word cloud

### Implementation Scope

1. **Engine installation script** — Shell script to install/verify the TTS engine
2. **Lua wrapper module** — `libs/tts-engine.lua` implementing the designed interface
3. **Configuration activation** — Uncomment and populate `tts` section in `config.lua`
4. **Pipeline integration** — Add TTS initialization to `run.sh`
5. **Validation** — Test script to verify TTS is working

### Expected File Structure

```
libs/
├── tts-engine.lua          # Main TTS wrapper module
└── tts-engine.info.md      # Function documentation

scripts/
└── install-tts.sh          # Engine installation script

assets/
└── audio-cache/            # Cached word audio files
    ├── silence.wav
    ├── memory.wav
    └── ...
```

## Suggested Implementation Steps

1. **Create installation script** — `scripts/install-tts.sh` for the chosen engine
2. **Implement `libs/tts-engine.lua`**:
   - `init(config)` — Initialize engine, verify binary/model exists
   - `generate_word_audio(word, output_path)` — Core synthesis function
   - `generate_cached(word, cache_dir)` — Cache-aware wrapper
   - `get_word_duration_ms(audio_path)` — Duration extraction (ffprobe or sox)
3. **Enable configuration** — Populate `config.lua` tts section with real values
4. **Add pipeline validation** — Verify TTS availability on `run.sh` startup
5. **Create test script** — Generate audio for 6 test words, verify playback
6. **Create `libs/tts-engine.info.md`** — Document external interface
7. **Test caching** — Verify cache hit/miss behavior

### Validation Script

```bash
#!/bin/bash
# scripts/test-tts.sh

DIR="${1:-$(dirname "$0")/..}"

echo "Testing TTS engine..."
luajit -e "
    package.path = '$DIR/libs/?.lua;' .. package.path
    local tts = require('tts-engine')
    local config = require('config-loader').load('$DIR/config.lua')

    tts.init(config.tts)

    local test_words = {'silence', 'memory', 'night', 'fire', 'window', 'dream'}
    for _, word in ipairs(test_words) do
        local path, cached = tts.generate_cached(word, config.tts.cache_dir)
        local duration = tts.get_word_duration_ms(path)
        print(string.format('%s: %dms (cached: %s)', word, duration, tostring(cached)))
    end
"
echo "TTS test complete. Audio files in: $DIR/assets/audio-cache/"
```

## Deliverables

- [ ] `scripts/install-tts.sh` — Engine installation script
- [ ] `libs/tts-engine.lua` — Full implementation
- [ ] `libs/tts-engine.info.md` — Interface documentation
- [ ] `config.lua` tts section enabled with real values
- [ ] `scripts/test-tts.sh` — Validation script
- [ ] All 6 test words successfully synthesized and cached
- [ ] Duration extraction working for cached files

## Testing

- Run `scripts/install-tts.sh` — Should complete without errors
- Run `scripts/test-tts.sh` — Should generate 6 audio files
- Run test script twice — Second run should report all cache hits
- Play audio files — Should sound natural and consistent

## Related Documents

- Issue 13-001: Research and Implement TTS Engine (parent)
- Issue 13-001a: Research TTS Options (provides engine selection)
- Issue 13-001b: Design TTS Integration Architecture (provides interface spec)
- Issue 13-002c: Generate Per-Word Audio Cache (downstream consumer)
- `libs/ollama-config.lua` — Reference implementation pattern
- `libs/config-loader.lua` — Configuration loading

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (implementation from spec)
- **Dependencies**: 13-001a (engine), 13-001b (architecture)
- **Blocks**: 13-002c
