# Phase 15 Progress Report

## Phase 15 Goals

**"Chromatic Encoding — Text as Color, Collection as Palette, Arrangement as Art"**

Phase 15 transforms semantic embeddings into colors, turning each poem/passage into a pixel. Artists arrange these pixels into images, and the arrangement itself becomes a reading order — the image IS the navigation sequence, frozen in color.

### **From Previous Phases**
- 768-dimensional embeddings for all poems
- Cosine similarity infrastructure
- Semantic color assignments (limited, to be expanded)
- Static HTML generation pipeline

### **Phase 15 Objectives**
- Design embedding→color mapping algorithms (PCA, anchor-based, modular overflow)
- Generate color palettes representing entire collections
- Create default arrangements (linear, similarity-chain)
- Implement bidirectional encoding: image↔reading sequence
- Enable artists to compose images from poem-pixels

## The Core Inversion

| Traditional | Chromatic Encoding |
|-------------|-------------------|
| Images illustrate text | Text constitutes the image |
| Reading is temporal | Reading is spatial |
| The author sequences | The artist arranges |
| Navigation is abstract | Navigation is visible |

## Phase 15 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 15-001 | Chromatic Text Encoding System (Vision) | Open | High |

### Sub-Issues (To Be Created)

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| 15-001a | Design embedding-to-color mapping algorithms | Planned |
| 15-001b | Generate poem color palette | Planned |
| 15-001c | Create default arrangements | Planned |
| 15-001d | Implement image→sequence decoder | Planned |
| 15-001e | Build encoded reading page generator | Planned |
| 15-001f | Interactive palette arrangement tool | Future |

### Completed Issues

None yet.

## Key Concepts

### Embedding → Color

Each 768-dimensional vector becomes RGB:

```
poem "silence" → [0.23, -0.15, 0.87, ...] → RGB(142, 87, 203) → █
```

### Mapping Strategies

| Strategy | Method | Character |
|----------|--------|-----------|
| **Naive** | First 3 dims | Fast, ignores most data |
| **Folded** | Sum groups of 256 | Uses all dims, loses structure |
| **PCA** | Project to 3D | Preserves variance, similar = similar color |
| **Anchored** | Similarity to R/G/B concepts | Semantic meaning → color meaning |
| **Modular** | Overflow arithmetic | Unexpected relationships |

### The Palette

~7,800 poems = ~7,800 pixels = a 89×88 image

Each pixel is a poem. The collection is a visual artifact.

### Encoded Reading Order

The spatial arrangement of pixels defines a reading sequence:

```
Image pixels: [P42, P17, P89, P3, ...]
Reading:      silence → fire → memory → ...
```

The image IS the navigation. Share the image, share the reading experience.

## Completion Criteria

- [ ] At least one embedding→color mapping algorithm implemented
- [ ] Poem color palette generated (`palette.json`, `palette.png`)
- [ ] Default arrangements created (linear, similarity-chain)
- [ ] Image→sequence decoder working
- [ ] Encoded reading pages generated
- [ ] Round-trip verified: poems → image → reading sequence

---

**Phase Status: OPEN**

**Created**: 2026-01-28

## Cross-Phase Dependencies

**Depends on:**
- Phase 1-8: Embedding infrastructure
- Optionally Phase 14: Book passages could also become pixels

**Enables:**
- Visual representation of literary collections
- Artist-curated reading experiences
- A new form of literary art: the chromatic arrangement

## Related Documents

- 15-001: Chromatic Text Encoding System (vision issue)
- `assets/embeddings/embeddinggemma_latest/poem_colors.json` — Existing color assignments
- `src/similarity-engine.lua` — Cosine similarity for anchor mapping
- Phase 14: Narrative Tapestry (complementary approach)

## Philosophical Note

> *The artist who arranges the pixels is not illustrating the work. They are editing it — choosing which poem follows which, creating a new path through meaning. The image is their editorial signature, frozen in color.*
