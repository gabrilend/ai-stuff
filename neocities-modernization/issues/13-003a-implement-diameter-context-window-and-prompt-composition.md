# Issue 13-003a: Implement Diameter Context Window and Prompt Composition

## Priority
High (blocks 13-003c)

## Parent Issue
13-003: Generate Stable Diffusion Visuals from Flopsopoly Sequence

## Current Behavior

After 13-002d completes, a trance track manifest exists with timestamped word positions. However, there is no logic to:
1. Extract context windows from the sequence for image generation
2. Compose stable diffusion prompts from word groups

## Intended Behavior

Implement the **diameter-based context window** algorithm and **prompt composition strategies** for stable diffusion image generation.

### Diameter-Based Context Window

The context window at position P extends equally in both directions, like a diameter centered on the current word:

```
Context window = [P - N/2, P + N/2]

Where N = configurable context diameter (e.g., 10 words)

Example with N=10 at position P=25:
  Words 20-30 form the prompt for image at position 25

  [20] fire
  [21] silence
  [22] memory    <- backward context (what was just spoken)
  [23] ocean
  [24] dream
  [25] NIGHT     <- current position (center of diameter)
  [26] window
  [27] love      <- forward context (what's coming next)
  [28] silence
  [29] shadow
  [30] garden
```

**Why diameter?** Just as a circle's diameter extends the same distance (radius) from the center in both directions, the context window includes both "what just happened" and "what's coming next" — creating visual continuity with foreshadowing.

### Boundary Handling

At sequence boundaries:
- Near the start (P < N/2): Window is `[1, N]` — more forward context
- Near the end (P > L - N/2): Window is `[L - N + 1, L]` — more backward context

```lua
local function get_context_window(sequence, position, diameter)
    local half = math.floor(diameter / 2)
    local window_start = math.max(1, position - half)
    local window_end = math.min(#sequence, position + half)

    -- Expand the other direction if clamped
    if window_start == 1 then
        window_end = math.min(#sequence, diameter)
    elseif window_end == #sequence then
        window_start = math.max(1, #sequence - diameter + 1)
    end

    local context = {}
    for i = window_start, window_end do
        table.insert(context, sequence[i])
    end
    return context
end
```

### Prompt Composition Strategies

Three strategies for converting context words into stable diffusion prompts:

#### Strategy 1: Simple Concatenation
```lua
-- "silence fire memory ocean dream night window love"
local function compose_prompt_simple(context_words)
    local words = {}
    for _, item in ipairs(context_words) do
        table.insert(words, item.word)
    end
    return table.concat(words, " ")
end
```

#### Strategy 2: Weighted by Font Size
```lua
-- "(silence:1.4) fire (memory:1.2) ocean dream (night:1.3) window love"
-- Higher font_size = more emphasis in the prompt
local function compose_prompt_weighted(context_words)
    local parts = {}
    for _, item in ipairs(context_words) do
        local weight = 1.0 + (item.font_size - 1) * 0.1  -- size 1 = 1.0, size 7 = 1.6
        if weight > 1.05 then
            table.insert(parts, string.format("(%s:%.1f)", item.word, weight))
        else
            table.insert(parts, item.word)
        end
    end
    return table.concat(parts, " ")
end
```

#### Strategy 3: Themed with Semantic Color
```lua
-- "blue toned, silence fire memory ocean dream night window love, ethereal"
-- Includes dominant semantic color from context window
local function compose_prompt_themed(context_words, config)
    local simple_prompt = compose_prompt_simple(context_words)
    local dominant_color = get_dominant_semantic_color(context_words)
    local theme_prefix = dominant_color .. " toned, "
    local theme_suffix = ", ethereal, dreamlike"
    return theme_prefix .. simple_prompt .. theme_suffix
end
```

### Configuration

```lua
-- In config.lua:
stable_diffusion = {
    context_diameter = 10,      -- N: words in context window
    prompt_style = "weighted",  -- "simple", "weighted", or "themed"
    include_color_theme = true, -- Add semantic color to prompt (for "themed")

    -- Prompt modifiers
    prompt_prefix = "",                    -- Added before all prompts
    prompt_suffix = ", high quality",      -- Added after all prompts
    negative_prompt = "text, watermark, blurry, low quality, deformed",
}
```

## Suggested Implementation Steps

1. **Implement `get_context_window(sequence, position, diameter)`** — Core windowing function
2. **Handle boundary cases** — Test at P=1, P=5, P=L-5, P=L
3. **Implement three prompt strategies**:
   - `compose_prompt_simple(context)`
   - `compose_prompt_weighted(context)`
   - `compose_prompt_themed(context, config)`
4. **Add strategy dispatcher** — Select based on config.prompt_style
5. **Integrate semantic color** — For themed strategy (optional, depends on 8-050a)
6. **Create test cases** — Verify window extraction and prompt generation
7. **Document in `libs/prompt-composer.info.md`**

### File Location

Create `libs/prompt-composer.lua` with the context window and prompt composition functions.

## Deliverables

- [ ] `libs/prompt-composer.lua` — Context window and prompt composition module
- [ ] `libs/prompt-composer.info.md` — Interface documentation
- [ ] `get_context_window(sequence, position, diameter)` function
- [ ] Three prompt composition strategies implemented
- [ ] Boundary handling tested at sequence edges
- [ ] Configuration schema in `config.lua`

## Testing

```lua
-- Test: context window extraction
local sequence = {}
for i = 1, 100 do sequence[i] = {word = "word" .. i, font_size = (i % 7) + 1} end

-- Middle of sequence
local ctx = get_context_window(sequence, 50, 10)
assert(#ctx == 10, "Expected 10 words in context")
assert(ctx[1].word == "word45", "Expected window to start at 45")
assert(ctx[10].word == "word54", "Expected window to end at 54")

-- Start of sequence
local ctx_start = get_context_window(sequence, 3, 10)
assert(ctx_start[1].word == "word1", "Expected window to start at 1")

-- End of sequence
local ctx_end = get_context_window(sequence, 98, 10)
assert(ctx_end[#ctx_end].word == "word100", "Expected window to end at 100")

-- Test: prompt composition
local context = {{word="silence", font_size=7}, {word="fire", font_size=2}}
local simple = compose_prompt_simple(context)
assert(simple == "silence fire", "Simple prompt mismatch")

local weighted = compose_prompt_weighted(context)
assert(weighted:find("silence:1.6"), "Weighted prompt missing emphasis")
```

## Related Documents

- Issue 13-003: Generate Stable Diffusion Visuals (parent)
- Issue 13-003b: Implement Stable Diffusion API Integration (uses prompts)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (orchestrates)
- Issue 13-002d: Assemble Trance Track and Manifest (provides sequence)
- Issue 8-050a: Word Semantic Color Assignments (for themed prompts)
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — For semantic color calculation

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (algorithm + prompt engineering)
- **Dependencies**: 13-002d (manifest with sequence)
- **Blocks**: 13-003c
