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
- Graceful failure: Continues on individual poem failures

**Output**: `/assets/embeddings/{model_name}/embeddings.json`

---

### Stage 5: Similarity Calculation

**Purpose**: Calculate pairwise similarity between all poems.

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
- **Purpose**: Document the complete data flow architecture for project understanding and onboarding
