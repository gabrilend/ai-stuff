# Issue 13-001: Research and Implement TTS Engine

## Priority
High (blocks 13-002)

## Current Behavior

No text-to-speech capability exists in the project. The pipeline generates static HTML and text files but has no audio output. The word cloud data (frequencies, embeddings, semantic colors) exists only as visual and textual information.

## Intended Behavior

Integrate a text-to-speech engine into the project that can:

1. Accept individual words as input
2. Generate spoken audio for each word
3. Support configurable voice parameters (speed, pitch, tone)
4. Run locally (no cloud API dependency)
5. Be callable from Lua or via a shell command
6. Output audio files (WAV or MP3) that can be concatenated into a continuous track

### Sub-Issues

This issue has been split into the following sub-issues:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| [13-001a](13-001a-research-tts-options.md) | Research TTS options — Survey engines, evaluate quality vs. performance | Open |
| [13-001b](13-001b-design-tts-integration-architecture.md) | Design TTS integration architecture — Interface, caching, config | Open |
| [13-001c](13-001c-implement-tts-integration.md) | Implement TTS integration — Build libs/tts-engine.lua | Open |

**Dependency chain**: 13-001a → 13-001b → 13-001c

## Research Considerations

### TTS Engine Candidates

| Engine | Quality | Speed | Local | Language | Notes |
|--------|---------|-------|-------|----------|-------|
| Piper | High | Fast | Yes | C++/Python | ONNX-based, many voices, lightweight |
| Coqui TTS | Very High | Medium | Yes | Python | Neural TTS, customizable, larger models |
| eSpeak-NG | Low | Very Fast | Yes | C | Robotic but ultra-fast, good for prototyping |
| Festival | Medium | Fast | Yes | C++ | Academic, extensible, older |
| Bark | Very High | Slow | Yes | Python | Generative audio, supports music/effects |
| Mozilla TTS | High | Medium | Yes | Python | Predecessor to Coqui |

### Key Requirements

1. **Local execution** — No cloud API (Anthropic, Google, Amazon) dependency
2. **Per-word generation** — Must handle individual words efficiently (not full sentences)
3. **Consistent voice** — Same voice/style across all words for trance cohesion
4. **Cacheability** — Generated audio for each word can be cached and reused
5. **Lua compatibility** — Callable via `io.popen()` or similar mechanism
6. **Quality threshold** — Must sound natural enough for a trance/meditation experience

### Integration Architecture Questions

- **Invocation model**: CLI binary (e.g., `piper --output-file word.wav "silence"`) vs. HTTP API (like Ollama)?
- **Caching strategy**: Pre-generate all word audio files? Or generate on-demand during flopsopoly assembly?
- **Audio format**: WAV (lossless, easy to concatenate) vs. MP3 (compressed, needs re-encoding for concat)?
- **Silence/spacing**: How much silence between words? Configurable? Variable based on semantic distance?
- **Configuration**: Where to store TTS settings? `config.lua`? New config section?

## Suggested Implementation Steps

1. **Create sub-issues** 13-001a (research), 13-001b (design), 13-001c (implementation)
2. **Survey TTS engines** — Install and test 2-3 candidates with sample words from the word cloud
3. **Evaluate quality** — Listen to "silence", "memory", "night", "fire" rendered by each engine
4. **Benchmark speed** — Time per word generation (need ~200-1400 words depending on repetition)
5. **Test Lua integration** — Verify the engine can be called from Lua scripts
6. **Select engine** — Document decision rationale in 13-001a
7. **Design interface** — Create Lua wrapper module in 13-001b
8. **Implement** — Build `libs/tts-engine.lua` or similar in 13-001c

## Related Documents

- Issue 13-002: Generate TTS Hypnotic Trance Track (downstream consumer)
- Issue 13-003: Generate Stable Diffusion Visuals (downstream consumer)
- `src/wordcloud-generator.lua` — Word frequency data source
- `libs/ollama-config.lua` — Reference for local service integration pattern

## Original Request Context

> Okay now can we make an issue file in a new phase, a phase related to audio generation from similar/different embedding similarity matrix identity convolutional declarative iteration style programming? The first issue file should be about researching and implementing a TTS engine. The first todo item in that issue file should be to split the file into sub-issues, for research, design, and implementation. The next issue file should be about passing all the words from the word-cloud generator through a TTS, with the frequency of each word corresponding to the "size" of the word in the word cloud. If the base size is 1, and there's a word with size 7, then 7 instances of that word will be placed in the pool of words to iterate through with the TTS engine. These 7 instances will be pseudo-deterministically ordered in a big pool of words, a flopsopoly of verbrases if you will. This flopsopoly will be ordered in the way that makes the most sense, as determined by a progressively expanding centroid calculation that calculates the most distant word from among all of the remaining words. Since there are duplicate words by design, it will add one of the duplicates to the centroid which will then reduce the likelihood that the centroid (selecting the most distant word) will select that word again until the centralized cluster has been shifted enough that the already-selected-word is now the farthest. This should provide for an interesting hypnotic experience that can be matched to visuals created by a locally run stable diffusion model (IP address and port required) which creates images based on a flopsopoly of verbrases that correspond to the N most recent words that have been added to the flopsopoly. Note that N is taken from the forward and backwards directions, like a diameter is the same distance from the central point at both ends as the radius of a circle might be. The images will be created after the TTS hypnotic trance track has been generated, which means the image related functionality should be another issue. Please include this message in all of the issue files for further reference.

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium-High (research + integration)
- **Dependencies**: None (foundational issue)
- **Blocks**: 13-002, 13-003
