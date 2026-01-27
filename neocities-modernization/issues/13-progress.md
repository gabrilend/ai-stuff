# Phase 13 Progress Report

## Phase 13 Goals

**"Audio-Visual Generation from Embedding Similarity Matrix Identity Convolutional Declarative Iteration Style Programming"**

Phase 13 transforms the poetry collection's semantic embedding data into audio and visual experiences. Using a text-to-speech engine and a locally-hosted stable diffusion model, this phase generates hypnotic trance tracks from frequency-weighted word sequences ("flopsopolies") and paired visual imagery. The core innovation is applying the project's existing diversity-chaining and centroid-expansion algorithms to audio/visual generation rather than HTML navigation.

### **From Previous Phases**
- Complete poetry dataset (7,797 poems) with embeddings
- Word cloud with frequency-weighted vocabulary (200+ words, sizes 1-7)
- Word embeddings cached in `word_embeddings.json`
- Semantic color assignments for words and poems
- Diversity chaining algorithm (`src/diversity-chaining.lua`)
- GPU-accelerated computation infrastructure (Vulkan compute)

### **Phase 13 Objectives**
- Research and implement a text-to-speech engine compatible with the Lua pipeline
- Generate frequency-weighted word sequences (flopsopolies) using centroid-expansion ordering
- Produce hypnotic TTS audio tracks from flopsopoly word sequences
- Generate paired visual content using a local stable diffusion model
- Create a multimedia experience that bridges semantic analysis and sensory output

## Phase 13 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 13-001 | Research and implement TTS engine | Open | High |
| 13-002 | Generate TTS hypnotic trance track from word-cloud flopsopoly | Open | High |
| 13-003 | Generate stable diffusion visuals from flopsopoly | Open | Medium |
| 13-004 | Assemble video from TTS audio and generated images | Open | Medium |

### Completed Issues

None yet.

## Key Concepts

### Flopsopoly of Verbrases

A **flopsopoly** is a frequency-weighted, centroid-diversified word sequence. Words from the word cloud are placed into a pool with repetition counts matching their font size (1-7 instances). The pool is then ordered using a progressive centroid expansion algorithm that maximizes diversity: at each step, the word most distant from the running centroid is selected. Duplicate words naturally space themselves out because selecting one instance shifts the centroid toward that word, making other instances temporarily less distant.

### Progressive Centroid Expansion

The same principle as the diversity chaining algorithm used for "different" pages, but applied to word embeddings with multiplied instances:
1. Start with empty centroid
2. Find word in pool most distant from centroid
3. Add to sequence, update centroid (running average)
4. Repeat until pool exhausted
5. Duplicates self-regulate: selection shifts centroid, reducing re-selection probability

### Diameter-Based Context Window

For image generation, the context window at position P in the flopsopoly is `[P - N/2, P + N/2]` — like a diameter centered on the current word. This means each image prompt includes both "what just happened" (backward) and "what's coming" (forward), creating visual continuity with foreshadowing.

## Target Hardware

- **CPU**: TTS engine execution (or GPU-accelerated TTS if available)
- **GPU**: Stable diffusion inference (local instance, IP:port configurable)
- **Storage**: Audio files (WAV/MP3), generated images (PNG)
- **Network**: Local stable diffusion API endpoint

## Completion Criteria

- [ ] TTS engine researched, selected, and integrated
- [ ] Flopsopoly generation algorithm implemented and tested
- [ ] Hypnotic trance audio track generated from word-cloud data
- [ ] Stable diffusion API integration working
- [ ] Visual sequence generated with diameter-based context windowing
- [ ] Audio and visual outputs can be combined/synchronized
- [ ] Assembled video file (MP4) with sharp-cut transitions between frames

---

**Phase Status: OPEN**

**Created**: 2026-01-26

## Cross-Phase Dependencies

**Depends on:**
- Phase 1-8: Complete poetry dataset, word cloud, and embedding infrastructure
- Phase 8-050a: Word semantic color assignments (for visual theming)
- Phase 9: GPU infrastructure (potential TTS acceleration)

**Enables:**
- Multimedia poetry exploration experiences
- Audio-visual meditation/trance tools from semantic data
- Novel applications of embedding diversity algorithms

## Related Documents

- `src/wordcloud-generator.lua` — Word frequency data source
- `src/diversity-chaining.lua` — Centroid expansion algorithm reference
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — Word embedding data
- `config.lua` — Word cloud configuration (sizes, frequencies)
