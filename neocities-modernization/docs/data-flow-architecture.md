# Data Flow Architecture

## Neocities Poetry Modernization Project

This document describes the complete data flow architecture of the poetry recommendation system, which transforms ~6,860 poems into an interconnected, explorable static website using semantic embeddings.

---

## Overview

The system follows a **seven-stage pipeline** that cleanly separates data generation (embeddings, similarity matrices) from data viewing (HTML generation). This separation of concerns isolates errors to smaller areas of interest and enables incremental processing.

### Design Philosophy

- **Flat HTML**: No JavaScript/CSS — pure semantic HTML that works anywhere, forever
- **Incremental Processing**: Cache intermediate results, only recompute what's changed
- **Dual Discovery**: Similarity (focused exploration) and diversity (expansive/"schizophrenic" exploration)
- **Local LLM**: Embedding generation via Ollama service, no external API dependencies

---

## Pipeline Stages

### Stage 1: Extraction

**Purpose**: Extract raw content from ZIP archives and legacy files into structured JSON.

**How Data Transforms**: Imagine unpacking suitcases after returning from three different trips. Each suitcase was packed by a different person using their own system — one folded everything neatly, another just stuffed things in, a third used vacuum bags. The extraction stage opens each suitcase and sorts the contents into labeled boxes based on where they came from: "things from the beach trip," "things from the mountain trip," "things from the city trip." The items themselves aren't changed — they're just organized so that the next person can find them without needing to know the original packing method.

```
┌──────────────────┐    ┌──────────────┐    ┌────────────────────────┐
│ ZIP Archives     │    │              │    │ input/fediverse/       │
│ - most-recent-29 │ →  │scripts/update│ →  │   files/poems.json     │
│ - similar-diff   │    │              │    │ input/messages/        │
│                  │    │              │    │   files/poems.json     │
│ compiled.txt     │    │              │    │ input/notes/           │
│ (legacy 4MB)     │    │              │    │   files/poems.json     │
└──────────────────┘    └──────────────┘    └────────────────────────┘
```

**Scripts involved**:
- `/scripts/update` - Orchestrates extraction
- `/scripts/zip-extractor.lua` - Handles ZIP archive extraction
- `/scripts/extract-fediverse.lua` - Processes Mastodon/fediverse JSON exports
- `/scripts/extract-messages.lua` - Processes message archives
- `/scripts/extract-notes.lua` - Processes note files

**Output**: Three category-specific JSON files in `input/*/files/poems.json`

---

### Stage 2: Parsing

**Purpose**: Unify all input sources into a single normalized dataset.

**How Data Transforms**: Think of a translator receiving letters written in three different languages. Each letter uses different conventions — some have dates at the top, some at the bottom, some use formal greetings, others are casual. The translator rewrites every letter into a single common language using a consistent format: sender's name here, date there, body text in this section. Each letter also receives a sequential filing number so it can be referenced later. The meaning of each letter is preserved exactly, but now anyone can read them all without needing to know the original languages or conventions.

```
┌────────────────────┐         ┌─────────────────────────────────┐
│ poem-extractor.lua │ ──────→ │ assets/poems.json               │
│                    │         │ - 6,860 poems                   │
│ Auto-detects:      │         │ - Unified structure             │
│ - JSON extracts    │         │ - Category metadata             │
│ - Legacy compiled  │         │ - Creation timestamps           │
└────────────────────┘         └─────────────────────────────────┘
```

**Key file**: `/src/poem-extractor.lua`

**Output structure**:
```json
{
  "poems": [
    {
      "id": "0001",
      "category": "fediverse|messages|notes",
      "content": "poem text...",
      "metadata": {
        "created_at": "2024-01-15T10:30:00Z",
        "source_id": "original_id_from_source"
      }
    }
  ],
  "metadata": {
    "total_poems": 6860,
    "extraction_date": "2024-12-23"
  }
}
```

**Output**: `/assets/poems.json` (10.9 MB)

---

### Stage 3: Validation

**Purpose**: Ensure data quality and detect anomalies.

**How Data Transforms**: A quality inspector walks through the warehouse with a clipboard. They don't move or change anything — they simply observe and take notes. "Item 247 has no label." "Item 1,892 appears to be an empty box." "Items 3,400 through 3,450 all arrived on the same day, which seems unusual." The inspector's report doesn't fix problems; it documents them so that someone can decide what to do. The original items remain untouched. This stage produces a companion document — a health report that travels alongside the main dataset.

```
┌────────────────────┐         ┌─────────────────────────────────┐
│ poem-validator.lua │ ──────→ │ assets/validation-report.json   │
│                    │         │ - Empty content detection       │
│ Checks:            │         │ - Missing field reports         │
│ - Structure        │         │ - Data inconsistencies          │
│ - Content quality  │         │ - Quality metrics               │
│ - Field presence   │         │                                 │
└────────────────────┘         └─────────────────────────────────┘
```

**Key file**: `/src/poem-validator.lua`

**Output**: `/assets/validation-report.json` (6.2 MB)

---

### Stage 4: Embedding Generation

**Purpose**: Transform poem text into 768-dimensional semantic vectors.

**How Data Transforms**: Imagine a master perfumer who can smell any flower and describe its essence using a standardized palette of 768 distinct scent notes — "three parts citrus, half part musk, two parts rain-on-pavement, zero parts vanilla," and so on. The perfumer reads each poem and distills it into this scent profile. Two poems about loneliness might have very similar profiles even if they use completely different words, while two poems that happen to share the word "blue" might smell nothing alike if one is about sadness and the other about the ocean. The original poems are not changed; each one simply receives a companion "scent card" that captures what it's *about* rather than what words it *uses*.

```
┌────────────────────┐         ┌─────────────────────────────────┐
│ similarity-engine  │         │ assets/embeddings/              │
│       +            │ ──────→ │   EmbeddingGemma_latest/        │
│ Ollama @ :10265    │         │     embeddings.json (64 MB)     │
│                    │         │                                 │
│ Model:             │         │ Structure:                      │
│ embeddinggemma     │         │ {poem_id: [768 floats], ...}    │
│ (768 dimensions)   │         │                                 │
└────────────────────┘         └─────────────────────────────────┘
```

**Key file**: `/src/similarity-engine.lua`

**Supported models**:
| Model | Dimensions | Notes |
|-------|------------|-------|
| `embeddinggemma:latest` | 768 | Default, recommended |
| `text-embedding-ada-002` | 1536 | OpenAI-compatible |
| `all-MiniLM-L6-v2` | 384 | Lightweight |

**Processing features**:
- Incremental: Only processes new/changed poems
- Per-model storage: Each model gets its own subdirectory
- Fail-fast: Stops immediately on any error with detailed diagnostics
  - Rationale: Silent failures lead to corrupt data. Better to fail hard with
    actionable error messages so issues can be identified and fixed at the source.
  - Error output includes: poem ID, context, and specific remediation steps

**Output**: `/assets/embeddings/{model_name}/embeddings.json`

---

### Stage 5: Similarity Calculation

**Purpose**: Calculate pairwise similarity between all poems.

**How Data Transforms**: Now that every poem has a scent card, we can hold any two cards up and ask "how similar do these smell?" A sommelier comparing wines doesn't need to see the grapes — they compare the tasting notes. This stage compares every poem's scent card against every other poem's scent card, producing a massive web of relationships: "Poem 42 and Poem 1,337 smell almost identical; Poem 42 and Poem 500 share nothing in common." Additionally, poems are sorted into broad "neighborhoods" based on their overall character — all the citrus-heavy poems might be tagged yellow, all the earthy ones brown. The scent cards themselves don't change; this stage produces a relationship map and a set of neighborhood assignments that sit alongside everything else.

```
┌────────────────────┐         ┌─────────────────────────────────┐
│ similarity-engine  │         │ similarity_matrix.json (263 KB) │
│                    │ ──────→ │ - Sparse matrix format          │
│ Algorithms:        │         │ - Only meaningful similarities  │
│ - Cosine (default) │         │                                 │
│ - Euclidean        │         │ poem_colors.json (639 KB)       │
│ - Manhattan        │         │ - Semantic color assignments    │
│ - 5+ others        │         │ - Clustering visualization      │
└────────────────────┘         └─────────────────────────────────┘
```

**Key files**:
- `/src/similarity-engine.lua` - Matrix calculation
- `/src/similarity-calculator.lua` - Modular algorithm implementations
- `/src/semantic-color-calculator.lua` - Color assignment

**Semantic colors**: `red`, `blue`, `green`, `purple`, `orange`, `yellow`, `gray`

**Output**:
- `/assets/embeddings/{model}/similarity_matrix.json`
- `/assets/embeddings/{model}/poem_colors.json`

---

### Stage 6: Diversity Chaining

**Purpose**: Pre-compute "maximally different" poem sequences for diversity exploration.

**How Data Transforms**: A travel agent is asked to plan a road trip that visits the most varied landscapes possible. If you start at a beach, the next stop should be mountains; after mountains, perhaps desert; after desert, a dense forest. The agent consults the relationship map and, for each possible starting point, charts a journey that maximizes contrast at every step. "If you begin at Poem 42 and want to experience maximum variety, visit Poem 3,201 next, then Poem 789, then Poem 4,455..." These itineraries are written down and filed away so that travelers don't have to wait for route planning — the journeys are pre-charted for every possible starting point.

```
┌────────────────────┐         ┌─────────────────────────────────┐
│ diversity-chaining │         │ diversity_temp/                 │
│       .lua         │ ──────→ │ - Pre-computed sequences        │
│                    │         │ - For each starting poem        │
│ Algorithm:         │         │ - Least-similar selection       │
│ Greedy selection   │         │                                 │
│ of least-similar   │         │                                 │
└────────────────────┘         └─────────────────────────────────┘
```

**Key files**:
- `/src/diversity-chaining.lua` - Core algorithm
- `/src/mass-diversity-generator.lua` - Batch processing

**Output**: `/assets/embeddings/{model}/diversity_temp/`

---

### Stage 7: HTML Generation

**Purpose**: Transform all computed data into static HTML pages.

**How Data Transforms**: A printing press takes everything assembled so far — the unified collection, the relationship map, the neighborhood colors, the pre-charted journeys — and stamps out thousands of interconnected pages. Each page is a doorway: step through one door and you see everything arranged by similarity; step through another and you're on the pre-charted diversity journey. The press works in parallel, running multiple print heads simultaneously to produce pages faster. Nothing new is computed here; the press simply renders all the previously-gathered knowledge into a format that humans can navigate with nothing more than a web browser and the ability to click links.

```
┌────────────────────────┐     ┌─────────────────────────────────┐
│ flat-html-generator    │     │ output/                         │
│          +             │     │   index.html (→ chronological)  │
│ generate-html-parallel │ ──→ │   chronological.html (12 MB)    │
│   (8 threads via effil)│     │   explore.html (1 KB)           │
│                        │     │   numeric-index.html (289 KB)   │
│ Template engine:       │     │   similar/0001..6860.html       │
│ /src/html-generator/   │     │   different/*.html              │
│   template-engine.lua  │     │                                 │
└────────────────────────┘     └─────────────────────────────────┘
```

**Key files**:
- `/src/flat-html-generator.lua` - Main generation logic
- `/scripts/generate-html-parallel` - Multi-threaded wrapper
- `/src/html-generator/template-engine.lua` - HTML templates
- `/src/html-generator/url-manager.lua` - Navigation URLs
- `/src/html-generator/golden-poem-bonus.lua` - Golden poem styling

**Generated pages**:
| Page Type | Count | Size | Description |
|-----------|-------|------|-------------|
| Chronological | 1 | 12 MB | Main entry, all poems in order |
| Explore | 1 | 1 KB | Discovery instructions |
| Numeric Index | 1 | 289 KB | CTRL+F searchable links |
| Similarity | ~6,400 | 8.5 MB each | Per-poem similarity rankings |
| Diversity | ~6,400 | varies | Per-poem diversity chains |

---

## Complete Data Flow Diagram

```
[ZIP Archives] → [scripts/update] → [Temp Extraction]
                                          │
[compiled.txt] ─────────────────→ [poem-extractor.lua]
[input/*/poems.json] ────────────→        │
                                    [assets/poems.json]
                                          │
                            ┌─────────────┴─────────────┐
                            ▼                           ▼
                    [poem-validator.lua]        [image-manager.lua]
                            │                           │
              [validation-report.json]      [image-catalog.json]

[Ollama Service] → [similarity-engine.lua] ← [poems.json]
                            │
              [embeddings/{model}/embeddings.json]
                            │
              [similarity_matrix.json]
                            │
              [poem_colors.json]
                            │
              [diversity sequences]
                            │
          [flat-html-generator.lua] ← [all data sources]
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
    [chronological.html]          [similar/*.html]
              │                           │
    [numeric-index.html]         [different/*.html]
              │
    [Final Website in /output/]
```

---

## Entry Points

| Command | Purpose |
|---------|---------|
| `./run.sh` | Full pipeline: update → extract → process → generate |
| `lua src/main.lua` | Core processing (non-interactive) |
| `lua src/main.lua -I` | Interactive mode for selective operations |
| `./generate-embeddings.sh` | Standalone embedding generation |
| `./phase-demo.sh` | Phase demonstration selector |

---

## Key Asset Files Summary

| File | Location | Size | Purpose |
|------|----------|------|---------|
| poems.json | /assets/ | 10.9 MB | Unified poem dataset |
| embeddings.json | /assets/embeddings/{model}/ | 64 MB | Semantic vectors |
| similarity_matrix.json | /assets/embeddings/{model}/ | 263 KB | Pairwise similarities |
| poem_colors.json | /assets/embeddings/{model}/ | 639 KB | Semantic color assignments |
| validation-report.json | /assets/ | 6.2 MB | Data quality report |
| image-catalog.json | /assets/ | 326 KB | Image metadata |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `/config/asset-paths.lua` | Configurable storage locations |
| `/config/golden-poem-settings.json` | Golden poem identification criteria |
| `/config/input-sources.json` | Input source configuration |
| `/config/semantic-colors.json` | Color mapping for categorization |
| `/config/similarity-calculator-settings.json` | Algorithm settings |

---

## External Dependencies

| Dependency | Purpose | Location |
|------------|---------|----------|
| Ollama | Embedding generation | `http://192.168.0.115:10265` |
| effil | Multi-threading | `/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/` |
| LuaJIT | Runtime | System |
| curl | HTTP requests | System |

---

## User Experience Flow

1. Reader arrives at `chronological.html`
2. Clicks any poem → lands on `/similar/XXXX.html`
3. Sees the selected poem at top, all others ranked by similarity
4. Can navigate deeper into similarity (focused exploration)
5. Can jump to `/different/XXXX.html` for diversity (expansive exploration)

The dual discovery modes serve different reading strategies:
- **Similarity**: Drill into a vein of thought
- **Diversity**: Deliberately break out of patterns

---

## Document History

- **Created**: December 23, 2025
- **Updated**: December 23, 2025 — Added "How Data Transforms" sections with analogies to each pipeline stage
- **Purpose**: Document the complete data flow architecture for project understanding and onboarding
