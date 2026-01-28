# Issue 15-001: Chromatic Text Encoding System

## Priority
Vision (Phase Foundation)

## Phase 15: Chromatic Encoding

> *Read the embeddings as if they were colors and use that to paint a pixel on an image that represents the work.*

## Current Behavior

The project generates 768-dimensional embeddings for poems and passages. These vectors are used for:
- Cosine similarity calculations
- Diversity/centroid expansion
- Semantic color assignment (existing, but limited)

The embeddings exist as abstract mathematical objects. Their visual potential is untapped.

## Intended Behavior

Transform embeddings into **colors**, turning each poem/passage into a **pixel**, enabling:

1. **Chromatic representation** — Each text becomes a colored pixel derived from its embedding
2. **Artistic arrangement** — Artists compose images by placing poem-pixels where they choose
3. **Encoded reading order** — The pixel arrangement defines a navigation sequence
4. **Reversible mapping** — An image can be "read" by following its pixel order

### The Embedding-to-Color Pipeline

Each 768-dimensional embedding becomes an RGB color:

```
Embedding: [0.23, -0.15, 0.87, 0.04, ..., -0.31]  (768 dims)
                            ↓
              Dimensionality Reduction / Mapping
                            ↓
Color:     RGB(142, 87, 203)  →  █ (purple pixel)
```

### Mapping Strategies

#### Strategy 1: First Three Dimensions (Naive)

```lua
local function embedding_to_color_naive(embedding)
    -- Use first 3 dimensions, normalize from [-1,1] to [0,255]
    local r = math.floor((embedding[1] + 1) / 2 * 255)
    local g = math.floor((embedding[2] + 1) / 2 * 255)
    local b = math.floor((embedding[3] + 1) / 2 * 255)
    return r, g, b
end
```

**Problem**: Ignores 765 dimensions of semantic information.

#### Strategy 2: Dimensional Folding

```lua
local function embedding_to_color_folded(embedding)
    -- Fold 768 dimensions into 3 by summing groups of 256
    local r, g, b = 0, 0, 0
    for i = 1, 256 do r = r + embedding[i] end
    for i = 257, 512 do g = g + embedding[i] end
    for i = 513, 768 do b = b + embedding[i] end

    -- Normalize to [0, 255]
    r = math.floor((r / 256 + 1) / 2 * 255)
    g = math.floor((g / 256 + 1) / 2 * 255)
    b = math.floor((b / 256 + 1) / 2 * 255)
    return r, g, b
end
```

**Benefit**: Uses all dimensions, but loses fine structure.

#### Strategy 3: PCA Projection

```lua
-- Pre-compute PCA on all embeddings, project to 3D
local function embedding_to_color_pca(embedding, pca_matrix)
    local projected = matrix_multiply(embedding, pca_matrix)  -- 768 → 3
    local r = math.floor((projected[1] + 1) / 2 * 255)
    local g = math.floor((projected[2] + 1) / 2 * 255)
    local b = math.floor((projected[3] + 1) / 2 * 255)
    return r, g, b
end
```

**Benefit**: Maximizes variance preservation. Semantically similar texts have similar colors.

#### Strategy 4: Similarity to Color Anchors

```lua
-- Define anchor embeddings for Red, Green, Blue
local color_anchors = {
    red = embed("fire anger passion blood war"),
    green = embed("nature growth forest calm peace"),
    blue = embed("water sky sadness depth ocean")
}

local function embedding_to_color_anchored(embedding)
    local r = cosine_similarity(embedding, color_anchors.red)
    local g = cosine_similarity(embedding, color_anchors.green)
    local b = cosine_similarity(embedding, color_anchors.blue)

    -- Similarities are [-1, 1], map to [0, 255]
    r = math.floor((r + 1) / 2 * 255)
    g = math.floor((g + 1) / 2 * 255)
    b = math.floor((b + 1) / 2 * 255)
    return r, g, b
end
```

**Benefit**: Semantic meaning directly maps to color. "Fiery" poems are red, "peaceful" poems are green.

#### Strategy 5: Modular Overflow (The "99 → 100" approach)

> *ignoring the parts of the percentage sign that are higher than 99 → 100 (the limit as 99 approaches 100)*

```lua
local function embedding_to_color_modular(embedding)
    -- Sum all dimensions, take modulo to "overflow" into color space
    local sum_r, sum_g, sum_b = 0, 0, 0

    for i = 1, 768, 3 do
        sum_r = sum_r + math.abs(embedding[i] or 0)
        sum_g = sum_g + math.abs(embedding[i+1] or 0)
        sum_b = sum_b + math.abs(embedding[i+2] or 0)
    end

    -- Modular overflow: values above 1.0 wrap around
    local r = math.floor((sum_r % 1.0) * 255)
    local g = math.floor((sum_g % 1.0) * 255)
    local b = math.floor((sum_b % 1.0) * 255)
    return r, g, b
end
```

**Benefit**: Creates unexpected color relationships. The "overflow" creates non-linear mappings.

### The Artist's Canvas

Once each poem has a color, the collection becomes a **palette**:

```
Poem "silence" → █ (deep blue)
Poem "fire"    → █ (bright orange)
Poem "memory"  → █ (soft purple)
Poem "window"  → █ (pale yellow)
...
```

The artist arranges these pixels to create an image:

```
┌────────────────────────────────┐
│ ██████████████████████████████ │
│ █  Arrangement by the Artist █ │
│ █    Each pixel is a poem    █ │
│ █   Position chosen freely   █ │
│ ██████████████████████████████ │
└────────────────────────────────┘
```

### Encoded Reading Order

The magic: **the image IS a reading order**.

```
Image pixels (left-to-right, top-to-bottom):
  Position 1: Poem #42 "silence"
  Position 2: Poem #17 "fire"
  Position 3: Poem #89 "memory"
  ...

This sequence becomes a navigation page:
  /encoded/artist-vision-01.html

Reading this page = experiencing the poems
in the order the artist chose to paint.
```

### Sharing and Decoding

The image can be shared as a `.png`. Anyone with the color→poem mapping can:
1. Load the image
2. Read pixels in order
3. Map colors back to poems (nearest color match)
4. Generate the reading sequence

```lua
-- {{{ local function decode_image_to_sequence
local function decode_image_to_sequence(image_path, poem_colors)
    local pixels = read_image_pixels(image_path)
    local sequence = {}

    for _, pixel in ipairs(pixels) do
        local nearest_poem = find_nearest_color_match(pixel, poem_colors)
        table.insert(sequence, nearest_poem)
    end

    return sequence
end
-- }}}
```

### Output Structure

```
output/
├── chromatic/
│   ├── palette.json           # {poem_id: {r, g, b}}
│   ├── palette.png            # Visual swatch of all poem colors
│   ├── palette.html           # Interactive palette browser
│   │
│   ├── arrangements/
│   │   ├── linear.png         # Default: chronological order
│   │   ├── similar-chain.png  # Arranged by similarity chain
│   │   ├── artist-001.png     # User-created arrangement
│   │   └── ...
│   │
│   └── encoded/
│       ├── linear.html        # Reading page for linear arrangement
│       ├── similar-chain.html # Reading page for similarity chain
│       ├── artist-001.html    # Reading page for artist arrangement
│       └── ...
```

### Interactive Palette Tool (Future)

A web-based tool where artists can:
1. See all poem-pixels in a palette
2. Drag and drop to arrange into images
3. Export the arrangement as both image and reading order
4. Share their chromatic compositions

## Technical Considerations

### Color Collision

Multiple poems may map to similar colors. Handling options:
- Allow collisions (decoding picks nearest match)
- Perturb colors slightly to ensure uniqueness
- Use higher bit depth (16-bit color)

### Image Dimensions

For ~7,800 poems:
- Square: 89×88 = 7,832 pixels
- Wide: 156×50 = 7,800 pixels
- Custom aspect ratios per arrangement

### Color Space

RGB is intuitive but alternatives exist:
- HSL: Hue = semantic category, Saturation = intensity, Lightness = length
- LAB: Perceptually uniform, better for similarity matching

## Original Request Context

> Can we also make an issue file to read the embeddings as if they were colors and use that to paint a pixel on an image that represents the work? Each paragraph poem could be compared to each of the color embedding numbers and then the combination of the values (normalized or by... ignoring the parts of the percentage sign that are higher than 99 → 100 (the limit as 99 approaches 100)) could be used to color the pixel. And they could be arranged by artists into images by using each of the pixels and placing it where they please. This could be "encoded" into text by creating a similar/different style page, except with the arrangement of the poems determined by the order that was chosen to create the image that the author made by using the pixels of the poems as they please.

## Suggested Sub-Issues

1. **15-001a: Design embedding-to-color mapping algorithms**
2. **15-001b: Generate poem color palette**
3. **15-001c: Create default arrangements (linear, similarity-chain)**
4. **15-001d: Implement image→sequence decoder**
5. **15-001e: Build encoded reading page generator**
6. **15-001f: (Future) Interactive palette arrangement tool**

## Related Documents

- Existing semantic color system (Phase 8)
- `assets/embeddings/embeddinggemma_latest/poem_colors.json` — Current color assignments
- `src/similarity-engine.lua` — Cosine similarity for anchor-based mapping
- Phase 14: Narrative Tapestry (complementary: text as space vs. text as color)

## Metadata

- **Status**: Open (Vision)
- **Created**: 2026-01-28
- **Phase**: 15 (Chromatic Encoding)
- **Estimated Complexity**: Medium (mapping algorithms + image I/O)
- **Dependencies**: Embeddings infrastructure (Phase 1-8)
- **Blocks**: 15-001a through 15-001f (sub-issues)

## Philosophical Note

This system inverts the usual relationship between text and image:

- Normally: Images illustrate text
- Here: Text constitutes the image

The image is not a representation OF the poems — it IS the poems, arranged spatially. Reading the image and reading the poems are the same act, viewed from different angles.

The artist who arranges the pixels is not illustrating the work. They are **editing** it — choosing which poem follows which, creating a new path through meaning. The image is their editorial signature, frozen in color.
