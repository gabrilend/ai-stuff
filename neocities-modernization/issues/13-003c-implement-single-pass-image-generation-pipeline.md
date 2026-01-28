# Issue 13-003c: Implement Single-Pass Image Generation Pipeline

## Priority
High (blocks 13-004)

## Parent Issue
13-003: Generate Stable Diffusion Visuals from Flopsopoly Sequence

## Current Behavior

After 13-003a (context window + prompts) and 13-003b (SD API) complete:
- Context window extraction is implemented
- Prompt composition strategies are available
- Stable diffusion API wrapper is functional

No orchestration exists to generate images for the full flopsopoly sequence.

## Intended Behavior

Implement the **single-pass image generation pipeline** that:
1. Loads the flopsopoly manifest from 13-002d
2. Iterates through sequence positions (all or every K-th)
3. Extracts context window at each position
4. Composes prompt from context words
5. Calls stable diffusion API to generate image
6. Saves image with positional filename
7. Generates visual manifest for downstream consumers

### Pipeline Overview

```
For each position P in sequence (or every K-th position):
    1. context = get_context_window(sequence, P, N)
    2. prompt = compose_prompt(context, strategy)
    3. image = sd.txt2img(prompt)
    4. save(image, "frame_{P:06d}.png")
    5. log(position, prompt, timing)
```

### Frame Interval (K)

Not every word needs a unique image. The `frame_interval` setting controls granularity:
- `frame_interval = 1`: One image per word (~700 images)
- `frame_interval = 3`: One image every 3 words (~230 images)
- `frame_interval = 5`: One image every 5 words (~140 images)

For video assembly (13-004), images are held for their corresponding word duration(s).

### Progress Display

```
Generating images: 50/700 (7%) - elapsed: 8m 20s - ETA: 1h 51m
  Current: "silence fire memory ocean dream"
  Last: frame_000049.png (12.3s)
```

## Technical Design

```lua
-- {{{ local function generate_flopsopoly_visuals
local function generate_flopsopoly_visuals(manifest_path, config)
    -- Load manifest
    local manifest = utils.read_json(manifest_path)
    local sequence = manifest.sequence

    -- Settings
    local N = config.context_diameter or 10
    local K = config.frame_interval or 1
    local output_dir = config.output_dir or "output/flopsopoly/visuals/pass1"

    -- Ensure output directory exists
    os.execute('mkdir -p "' .. output_dir .. '"')

    -- Verify SD connection
    local connected, err = sd.check_connection()
    if not connected then
        error("Stable diffusion not reachable: " .. (err or "unknown"))
    end

    -- Generate images
    local visual_manifest = {frames = {}}
    local total_positions = math.ceil(#sequence / K)
    local start_time = os.time()

    for i, p in ipairs(get_positions_to_generate(#sequence, K)) do
        -- Extract context and compose prompt
        local context = prompt_composer.get_context_window(sequence, p, N)
        local prompt = prompt_composer.compose_prompt(context, config.prompt_style)

        -- Generate image
        local image_filename = string.format("frame_%06d.png", p)
        local image_path = output_dir .. "/" .. image_filename

        local gen_start = os.time()
        local success, err = sd.txt2img(prompt, image_path, config)
        local gen_time = os.time() - gen_start

        if success then
            -- Add to visual manifest
            table.insert(visual_manifest.frames, {
                position = p,
                center_word = sequence[p].word,
                context_words = extract_words(context),
                prompt = prompt,
                image_file = image_filename,
                audio_start_ms = sequence[p].start_ms,
                audio_end_ms = sequence[p].end_ms,
                generation_time_s = gen_time
            })

            -- Progress display
            display_progress(i, total_positions, start_time, gen_time, prompt)
        else
            -- Log error but continue
            io.stderr:write(string.format("Failed at position %d: %s\n", p, err or "unknown"))
        end
    end

    -- Save visual manifest
    visual_manifest.total_frames = #visual_manifest.frames
    visual_manifest.context_diameter = N
    visual_manifest.frame_interval = K
    visual_manifest.prompt_style = config.prompt_style
    visual_manifest.created = os.date("!%Y-%m-%dT%H:%M:%SZ")

    utils.write_json(output_dir .. "/../visual-manifest.json", visual_manifest)

    return visual_manifest
end
-- }}}
```

### ETA Calculation

```lua
-- {{{ local function display_progress
local function display_progress(current, total, start_time, last_gen_time, prompt)
    local elapsed = os.time() - start_time
    local avg_time = elapsed / current
    local remaining = (total - current) * avg_time
    local eta_min = math.floor(remaining / 60)
    local eta_sec = remaining % 60

    io.write(string.format(
        "\rGenerating: %d/%d (%d%%) - elapsed: %s - ETA: %dm %ds    ",
        current, total,
        math.floor(current / total * 100),
        format_duration(elapsed),
        eta_min, eta_sec
    ))
    io.flush()

    -- Show current prompt on separate line (truncated)
    local short_prompt = prompt:sub(1, 60) .. (prompt:len() > 60 and "..." or "")
    io.write(string.format("\n  Current: \"%s\" (%.1fs)\n\027[2A",
        short_prompt, last_gen_time))
end
-- }}}
```

### CLI Integration

```bash
# In run.sh:
if [[ "$GENERATE_SD_VISUALS" == "true" ]]; then
    log_info "Generating stable diffusion visuals..."

    # Verify endpoint is configured
    if [[ -z "$SD_ENDPOINT" ]]; then
        log_error "stable_diffusion.endpoint not configured"
        exit 1
    fi

    luajit "$DIR/src/flopsopoly-visual-generator.lua" "$DIR"
fi
```

```bash
# CLI flags:
--sd-visuals           # Enable visual generation
--sd-endpoint URL      # Stable diffusion API endpoint
--sd-context N         # Context diameter (default: 10)
--sd-interval K        # Frame interval (default: 1)
--sd-prompt-style S    # "simple", "weighted", "themed"
--sd-test              # Generate only 5 test images
```

## Suggested Implementation Steps

1. **Create `src/flopsopoly-visual-generator.lua`** — Main orchestration script
2. **Implement position iteration** — Support frame_interval
3. **Integrate prompt composer** — Use 13-003a functions
4. **Integrate SD API** — Use 13-003b module
5. **Implement progress display** — ETA, current prompt, generation time
6. **Generate visual manifest** — Track all frames with metadata
7. **Add test mode** — `--sd-test` generates 5 sample images only
8. **Add pipeline integration** — `run.sh` flags
9. **Create output structure** — `output/flopsopoly/visuals/pass1/`

## Deliverables

- [ ] `src/flopsopoly-visual-generator.lua` — Main generation script
- [ ] Progress display with ETA
- [ ] Test mode (5 images only)
- [ ] Visual manifest: `output/flopsopoly/visuals/visual-manifest.json`
- [ ] Generated images: `output/flopsopoly/visuals/pass1/frame_NNNNNN.png`
- [ ] CLI integration in `run.sh`
- [ ] Error handling: log failures, continue generation

## Configuration

```lua
-- In config.lua:
stable_diffusion = {
    endpoint = "",              -- Required: "http://IP:PORT"
    context_diameter = 10,      -- N: words in context window
    frame_interval = 1,         -- K: generate every K-th position
    prompt_style = "weighted",  -- "simple", "weighted", "themed"

    -- Generation settings
    width = 1024,
    height = 1024,
    steps = 20,
    cfg_scale = 7.0,

    -- Output
    output_dir = "output/flopsopoly/visuals",
}
```

## Output Structure

```
output/flopsopoly/
├── trance-track.wav                    # From 13-002d
├── trance-track-manifest.json          # From 13-002d
├── visuals/
│   ├── pass1/                          # Single-pass output
│   │   ├── frame_000001.png
│   │   ├── frame_000002.png
│   │   ├── ...
│   │   └── frame_000700.png
│   └── visual-manifest.json            # Frame metadata
```

### Visual Manifest Format

```json
{
    "frames": [
        {
            "position": 1,
            "center_word": "silence",
            "context_words": ["silence", "fire", "memory", "ocean", "dream"],
            "prompt": "(silence:1.6) fire memory ocean dream",
            "image_file": "frame_000001.png",
            "audio_start_ms": 0,
            "audio_end_ms": 620,
            "generation_time_s": 12.3
        },
        ...
    ],
    "total_frames": 700,
    "context_diameter": 10,
    "frame_interval": 1,
    "prompt_style": "weighted",
    "created": "2026-01-28T12:00:00Z"
}
```

## Testing

```bash
# Test mode: generate 5 images
./run.sh --sd-visuals --sd-test --sd-endpoint "http://localhost:7860"

# Verify output
ls -la output/flopsopoly/visuals/pass1/
# Should show 5 PNG files

# Verify manifest
cat output/flopsopoly/visuals/visual-manifest.json | jq '.total_frames'
# Should output: 5
```

## Performance Notes

Image generation dominates runtime:
- Per image: 5-30 seconds (depending on model, steps, resolution)
- For 700 frames at 15s/frame: ~2.9 hours
- For 230 frames (interval=3) at 15s/frame: ~58 minutes

Consider:
- Lower `steps` for faster generation (20 → 15)
- Higher `frame_interval` for fewer images
- Running overnight for full generation

## Edge Cases

- **SD endpoint not configured**: Error with setup instructions
- **SD API timeout**: Retry once, log failure, continue to next frame
- **Disk space**: Estimate storage needed (700 × ~2MB = ~1.4GB)
- **Interrupted generation**: Visual manifest tracks completed frames; consider resume capability

## Related Documents

- Issue 13-003: Generate Stable Diffusion Visuals (parent)
- Issue 13-003a: Implement Diameter Context Window and Prompt Composition (provides prompts)
- Issue 13-003b: Implement Stable Diffusion API Integration (provides SD calls)
- Issue 13-003d: Implement Multi-Pass Refinement Mode (extends this pipeline)
- Issue 13-004: Assemble Video (consumes visual manifest)
- Issue 13-002d: Assemble Trance Track and Manifest (provides input manifest)

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium-High (pipeline orchestration)
- **Dependencies**: 13-003a (prompts), 13-003b (SD API), 13-002d (audio manifest)
- **Blocks**: 13-004
