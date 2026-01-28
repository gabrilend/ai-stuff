# Issue 13-003d: Implement Multi-Pass Refinement Mode

## Priority
Medium (optional enhancement, not on critical path)

## Parent Issue
13-003: Generate Stable Diffusion Visuals from Flopsopoly Sequence

## Current Behavior

After 13-003c completes, single-pass image generation works:
- Each image is generated from a text prompt only
- Images are independent — no visual continuity between adjacent frames
- The semantic meaning is encoded only through the word prompts

## Intended Behavior

Implement an **optional multi-pass refinement mode** that performs two or more passes over the image sequence. On subsequent passes, previously generated images are fed back into the stable diffusion context alongside the words, baking deeper semantic meaning into the visual output.

### How It Works

1. **Pass 1 (baseline)**: Generate images using only word context (standard diameter window)
2. **Pass 2+ (refinement)**: Generate images using words AND previous-pass images as context

### Image Context Window

On refinement passes, the image context reaches **twice as far** as the word context:

```
Pass 2+ context at position P, with word diameter N=4:

  Word context:    [P-2, P+2]   (N/2 each direction = 4 words total)
  Image context:   [P-4, P+4]   (N each direction = 8 images from previous pass)

  Why wider? Images from pass 1 already encode the word semantics of their own
  neighborhoods. By reaching further, pass 2 images absorb semantic information
  from a broader region — the previous images carry "pre-digested" meaning that
  propagates through the sequence like a wave.
```

### Weighting

The input images should have roughly the **same weight as the words** in the AI context:
- **img2img approach**: Use previous pass image at ~0.5 denoising strength
- **IP-Adapter approach**: Weight image embeddings equally with text embeddings
- **Composite input**: Blend neighbor images into a grid before passing as init_image

### Semantic Propagation

Each pass compounds semantic depth:
- **Pass 1**: Images encode local word meaning
- **Pass 2**: Images encode local + neighbor meaning
- **Pass 3**: Images encode local + neighbor + neighbor-of-neighbor meaning

The semantic field propagates outward with each pass, creating visual coherence across the entire sequence.

### Example with 3 Passes and N=4

```
Pass 1: Words only
  Position 25: prompt = "silence fire memory ocean"
  → generates frame_000025_pass1.png

Pass 2: Words + Pass 1 images
  Position 25: prompt = "silence fire memory ocean"
              + images from pass 1: frames 21-29 (4 back, 4 forward)
  → generates frame_000025_pass2.png (richer, absorbs neighbor semantics)

Pass 3: Words + Pass 2 images
  Position 25: prompt = "silence fire memory ocean"
              + images from pass 2: frames 21-29
  → generates frame_000025_pass3.png (even deeper semantic baking)
```

## Technical Design

### Configuration

```lua
-- In config.lua:
stable_diffusion = {
    -- ... base settings from 13-003b ...

    multi_pass = {
        enabled = false,              -- Toggle on/off
        num_passes = 2,               -- Total passes (1 = single, 2+ = refinement)
        image_context_multiplier = 2, -- Image reach = N × multiplier per direction
        image_weight = 0.5,           -- Weight of previous images vs words (0-1)
        denoising_strength = 0.5,     -- img2img: how much to change from previous
    },
}
```

### Refinement Pass Algorithm

```lua
-- {{{ local function generate_refinement_pass
local function generate_refinement_pass(sequence, prev_pass_dir, output_dir, pass_num, config)
    local N = config.context_diameter or 10
    local K = config.frame_interval or 1
    local image_reach = N * (config.multi_pass.image_context_multiplier or 2)

    for i, p in ipairs(get_positions_to_generate(#sequence, K)) do
        -- Word context (same as single-pass)
        local word_context = prompt_composer.get_context_window(sequence, p, N)
        local prompt = prompt_composer.compose_prompt(word_context, config.prompt_style)

        -- Image context (wider reach)
        local image_context = get_image_context(prev_pass_dir, p, image_reach, K)

        -- Composite previous images into init_image
        local init_image = composite_context_images(image_context)

        -- Generate with img2img
        local output_filename = string.format("frame_%06d.png", p)
        local output_path = output_dir .. "/" .. output_filename

        sd.img2img(prompt, init_image, output_path, {
            denoising_strength = config.multi_pass.denoising_strength or 0.5
        })

        display_progress(i, total, pass_num)
    end
end
-- }}}
```

### Image Compositing

Combine context images into a single init_image for img2img:

```lua
-- {{{ local function composite_context_images
-- Composites multiple images into a grid for img2img input
local function composite_context_images(image_paths)
    if #image_paths == 0 then
        return nil  -- Fall back to txt2img
    end

    if #image_paths == 1 then
        return image_paths[1]  -- Single image, no compositing needed
    end

    -- Create grid using ImageMagick montage
    local grid_path = DIR .. "/tmp/context_grid.png"
    local cols = math.ceil(math.sqrt(#image_paths))

    local cmd = string.format(
        'montage %s -tile %dx -geometry +0+0 -background black "%s"',
        table.concat(image_paths, " "),
        cols,
        grid_path
    )
    os.execute(cmd)

    return grid_path
end
-- }}}
```

### Alternative: IP-Adapter Approach

If the SD instance supports IP-Adapter:

```lua
-- {{{ local function generate_with_ip_adapter
local function generate_with_ip_adapter(prompt, context_images, output_path, config)
    local payload = {
        prompt = prompt,
        -- IP-Adapter specific fields
        ip_adapter_images = encode_images_base64(context_images),
        ip_adapter_scale = config.multi_pass.image_weight or 0.5,
        -- ... other settings
    }

    -- Call appropriate API endpoint
    return sd.call_api("/sdapi/v1/txt2img", payload, output_path)
end
-- }}}
```

## Suggested Implementation Steps

1. **Add multi_pass configuration** — Toggle and settings in `config.lua`
2. **Implement image context extraction** — Get neighboring images from previous pass
3. **Implement image compositing** — Montage grid or blend
4. **Implement refinement pass generation** — Loop with img2img calls
5. **Orchestrate multiple passes** — Pass 1, then pass 2, etc.
6. **Create output directories** — `pass1/`, `pass2/`, `final/`
7. **Symlink final pass** — `final/` → latest pass for downstream consumers
8. **Update visual manifest** — Track pass information
9. **Add CLI flags** — `--sd-multi-pass`, `--sd-passes N`

## Deliverables

- [ ] Multi-pass configuration schema in `config.lua`
- [ ] `get_image_context(dir, position, reach, interval)` function
- [ ] `composite_context_images(paths)` function
- [ ] `generate_refinement_pass(...)` function
- [ ] Pass orchestration in `src/flopsopoly-visual-generator.lua`
- [ ] Output directories: `pass1/`, `pass2/`, `final/`
- [ ] Visual manifest updated with pass information
- [ ] CLI flags: `--sd-multi-pass`, `--sd-passes`

## Output Structure (Multi-Pass)

```
output/flopsopoly/visuals/
├── pass1/                      # Single-pass output (or pass 1 of multi-pass)
│   ├── frame_000001.png
│   └── ...
├── pass2/                      # Refinement pass 2
│   ├── frame_000001.png
│   └── ...
├── pass3/                      # Refinement pass 3 (if configured)
│   └── ...
├── final/                      # Symlinks to latest pass
│   ├── frame_000001.png → ../pass2/frame_000001.png
│   └── ...
└── visual-manifest.json        # Updated with pass info
```

### Updated Visual Manifest

```json
{
    "frames": [...],
    "total_frames": 700,
    "multi_pass": {
        "enabled": true,
        "num_passes": 2,
        "image_context_multiplier": 2,
        "denoising_strength": 0.5
    },
    "final_pass": 2,
    "pass_directories": ["pass1", "pass2"],
    "created": "2026-01-28T12:00:00Z"
}
```

## Testing

```bash
# Test multi-pass with 5 images, 2 passes
./run.sh --sd-visuals --sd-test --sd-multi-pass --sd-passes 2

# Verify both passes generated
ls output/flopsopoly/visuals/pass1/ | wc -l  # Should be 5
ls output/flopsopoly/visuals/pass2/ | wc -l  # Should be 5

# Verify final symlinks
ls -la output/flopsopoly/visuals/final/
# Should show symlinks to pass2/
```

## Performance Notes

Multi-pass multiplies generation time:
- 2 passes: 2× generation time
- 3 passes: 3× generation time

For 700 frames at 15s/frame:
- Single pass: ~2.9 hours
- 2 passes: ~5.8 hours
- 3 passes: ~8.7 hours

Consider running overnight or with higher frame_interval.

## Edge Cases

- **Pass 1 incomplete**: Error on pass 2 if previous pass images missing
- **Different frame_interval between passes**: Not supported, error
- **ImageMagick not installed**: Fallback to single-image init (no compositing)
- **Very wide image reach**: Warn if reach exceeds sequence length

## Related Documents

- Issue 13-003: Generate Stable Diffusion Visuals (parent)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (base implementation)
- Issue 13-003b: Implement Stable Diffusion API Integration (provides img2img)
- Issue 13-004: Assemble Video (consumes final pass)

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: High (novel algorithm + image processing)
- **Dependencies**: 13-003c (single-pass pipeline)
- **Blocks**: None (optional enhancement)
