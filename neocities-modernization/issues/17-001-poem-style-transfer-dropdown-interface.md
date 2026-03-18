# Issue 17-001: Poem Style Transfer Dropdown Interface

## Status
- **Phase**: 17 (Future - Embedding Manipulation)
- **Priority**: Low
- **Type**: Feature Request
- **Status**: Open
- **Created**: 2026-03-18

## Overview

An interactive feature allowing users to combine the semantic content of one poem with the stylistic presentation of another, generating new visual or textual outputs.

## Current Behavior

Users browse poems individually. Navigation is limited to similar/different/chronological paths. There's no way to interactively combine or manipulate poem embeddings.

## Intended Behavior

### User Flow

1. User browses poems on the site
2. User clicks a dropdown menu on a poem's page
3. Dropdown shows:
   - User's pinned favorites (if available)
   - Curated collection (fallback if no favorites)
4. User selects a "style source" poem from the dropdown
5. System displays generated content that combines:
   - **Semantic meaning** from the current poem (what it says)
   - **Presentation style** from the selected poem (how it's said)

### Visual Concept

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Poem #1234: "the morning light spills..."                                   │
│                                                                             │
│ [ Style this poem as: ▼ ]                                                   │
│   ┌────────────────────────────────────────┐                                │
│   │ ★ Favorite: "electric dreams"          │                                │
│   │ ★ Favorite: "rust and renewal"         │                                │
│   │ ─────────────────────────────────────  │                                │
│   │ Curated: "chaos and clarity"           │                                │
│   │ Curated: "terminal velocity"           │                                │
│   └────────────────────────────────────────┘                                │
│                                                                             │
│ [Generated output appears below when style is selected]                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Generation Approach

Rather than "melange-style soup" (uniform blending), use uneven vector manipulation:

```
Content poem embedding: V_content
Style poem embedding:   V_style

# Uneven directional shift
V_result = V_content + (0.4 * direction_1) + (-0.6 * direction_2)

# Where directions are derived from style embedding components
# Then allow the result to "normalize" (similar to training process)
```

This creates outputs that preserve distinct characteristics from each source rather than averaging them into mush.

## Implementation Components

### 1. Frontend: Dropdown Interface

```html
<select id="style-dropdown" onchange="applyStyle(this.value)">
  <option value="">Select style source...</option>
  <optgroup label="Your Favorites">
    <option value="poem-3721">electric dreams</option>
  </optgroup>
  <optgroup label="Curated Collection">
    <option value="poem-0042">chaos and clarity</option>
  </optgroup>
</select>
```

Initially: dropdown auto-active (visible by default)
Later: hidden until requested (as content library grows)

### 2. Backend: Style Transfer Engine

New module: `libs/style-transfer.lua`

```lua
-- {{{ local function compute_style_transfer
local function compute_style_transfer(content_embedding, style_embedding, params)
    -- Compute directional vectors
    local direction = vector_subtract(style_embedding, content_embedding)

    -- Uneven application
    local result = vector_add(content_embedding,
        vector_scale(direction, params.positive_weight),
        vector_scale(negate(direction), params.negative_weight)
    )

    -- Normalize
    return normalize_embedding(result)
end
-- }}}
```

### 3. Cached Results

Pre-compute popular combinations:
- Favorites x Curated = N x M combinations
- Store in `cache/style-transfer/`
- Filename: `{content_id}-styled-as-{style_id}.json`

### 4. Output Options

Generated content could be:
- **Text**: LLM-generated text matching the style
- **Image**: Stable Diffusion image with style-transferred prompt
- **Both**: Combined presentation

## Abstraction for Reuse

This feature should be genericized for any embedding-based dataset:

```lua
-- Generic style transfer API
local StyleTransfer = require("libs/style-transfer")

local result = StyleTransfer.apply({
    content_embedding_path = "/path/to/embeddings.json",
    content_index = 1234,
    style_embedding_path = "/path/to/style-embeddings.json",
    style_index = 5678,
    similarity_matrix_path = "/path/to/similarity.bin",
    output_image_path = "/path/to/output.png"
})
```

## Suggested Implementation Steps

### Phase A: Infrastructure
1. [ ] Create `libs/style-transfer.lua` module
2. [ ] Implement uneven vector manipulation functions
3. [ ] Add normalization and validation

### Phase B: Computation
4. [ ] Define curated collection (10-20 style-source poems)
5. [ ] Build pre-computation pipeline for style combinations
6. [ ] Store results in cache directory

### Phase C: Frontend
7. [ ] Add dropdown HTML to poem page template
8. [ ] Implement JavaScript for dropdown interaction
9. [ ] Style the dropdown to match site aesthetic

### Phase D: Generation
10. [ ] Integrate with Stable Diffusion (Issue 13-003)
11. [ ] Generate images for each style combination
12. [ ] Display generated content on selection

### Phase E: User Features
13. [ ] Add "pin as favorite" functionality
14. [ ] Store user favorites (localStorage or server)
15. [ ] Auto-hide dropdown when empty

## Related Documents

- Issue 13-003: Stable Diffusion visuals from flopsopoly
- Issue 13-001: TTS engine research (for audio output option)
- `libs/vulkan-compute/` - GPU acceleration for vector operations
- `output/embeddings.json` - Poem embeddings
- `cache/similarity-matrix/` - Pre-computed similarities

## Classification

This feature is classified as a **"toy"** - an interactive exploration tool rather than core functionality. Links to this and similar embedding manipulation tools should be collected under a "toys" section in the site navigation.

## Notes from Original Request

> "essentially, combining the forms of two disparate poems, and generating something
> that was the same message as one, but the presentation style of the other."

> "stored monorepo-wide, and genericized like the scripts/ and libs/ directory."

> "then make it abstractable to any AI embedding generated dataset (like the similarity matrix and embedding array)"

---

## Implementation Log

(To be filled during implementation)
