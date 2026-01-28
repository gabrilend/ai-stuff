# Phase 14 Progress Report

## Phase 14 Goals

**"Narrative Tapestry — From Spindle to Woven Cloth"**

Phase 14 extends the semantic navigation system from poems to long-form narrative. By segmenting books into passages and applying the same embedding/similarity infrastructure, readers can navigate stories through semantic relationship rather than purely linear sequence.

> *The truth is, the story is what's important, and it's often best told with chains of words strung together into a long message starting from the beginning and going until the end, with breakpoints interspersed throughout so you don't lose track of the thought. However, I can't help but wonder if we take that spindle of thread and we wove it into a tapestry, guided by modern technology (LLMs) and assembling something greater than us and ourselves.*

### **From Previous Phases**
- Complete embedding infrastructure (Ollama + EmbeddingGemma)
- Similarity matrix computation (triangular storage, GPU acceleration)
- Similar/Different/Chronological navigation paradigm
- Static HTML generation pipeline
- Word cloud and semantic color systems

### **Phase 14 Objectives**
- Adapt the system to process book-length texts
- Implement intelligent passage segmentation (paragraph-based, with bundling)
- Generate navigable book representations with Similar/Different/Chronological pages
- Test with diverse text types (fables, philosophy, poetry, fiction)
- Explore what new meanings emerge when linear narrative becomes navigable tapestry

## Phase 14 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 14-001 | Book Tapestry Navigation System (Vision) | Open | High |

### Sub-Issues (To Be Created)

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| 14-001a | Design book input format and metadata schema | Planned |
| 14-001b | Implement passage segmentation algorithm | Planned |
| 14-001c | Adapt embedding pipeline for book passages | Planned |
| 14-001d | Generate book-specific HTML templates | Planned |
| 14-001e | Test with sample texts | Planned |

### Completed Issues

None yet.

## Key Concepts

### The Spindle and the Tapestry

Traditional reading treats a book as a **spindle of thread** — you follow it from beginning to end. This system weaves that thread into a **tapestry** where:

- **Similar navigation**: Find passages that resonate with what you just read
- **Different navigation**: Seek contrast and surprise
- **Chronological navigation**: Return to the original linear flow

The author's words remain unchanged. Only the reader's path through them expands.

### Passage Segmentation

Books are divided into **passages** (typically paragraphs), with small passages bundled together:

```
Paragraph 1 (50 chars)  ─┐
Paragraph 2 (30 chars)   ├─→ Passage 1 (180 chars)
Paragraph 3 (100 chars) ─┘

Paragraph 4 (500 chars) ───→ Passage 2 (500 chars)

Paragraph 5 (80 chars)  ─┐
Paragraph 6 (200 chars) ─┴─→ Passage 3 (280 chars)
```

This ensures each passage has enough semantic content for meaningful embedding.

### Suitable Texts

**Well-suited:**
- Episodic narratives (fables, mythology)
- Non-linear structures (experimental fiction)
- Philosophical texts (aphorisms, meditations)
- Poetry collections (already proven)
- Sacred texts (designed for cross-reference)

**Less suited (but still interesting):**
- Tightly plotted mysteries (spoiler structure)
- Character-driven novels (emotional arcs)

## Target Sample Texts

Public domain candidates for testing:
1. **Aesop's Fables** — Short, episodic, thematically rich
2. **Meditations by Marcus Aurelius** — Aphoristic, non-linear by nature
3. **Grimm's Fairy Tales** — Episodic, thematic patterns
4. **The Prophet by Kahlil Gibran** — Poetic prose, thematic chapters

## Completion Criteria

- [ ] Book input format and metadata schema defined
- [ ] Passage segmentation algorithm implemented
- [ ] Embedding pipeline adapted for book-length texts
- [ ] HTML templates created for book navigation
- [ ] At least one sample book successfully processed
- [ ] Similar/Different/Chronological navigation functional

---

**Phase Status: OPEN**

**Created**: 2026-01-28

## Cross-Phase Dependencies

**Depends on:**
- Phase 1-8: Embedding infrastructure, HTML generation, similarity computation
- Phase 9: GPU acceleration (for large books)

**Enables:**
- New forms of literary exploration
- Multi-book corpus navigation (future)
- Comparative literature tools

## Related Documents

- 14-001: Book Tapestry Navigation System (vision issue)
- `src/similarity-engine.lua` — Core similarity computation
- `src/diversity-chaining.lua` — Different page algorithm
- `src/flat-html-generator.lua` — HTML generation patterns
