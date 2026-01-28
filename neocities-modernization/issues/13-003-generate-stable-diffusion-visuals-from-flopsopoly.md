# Issue 13-003: Generate Stable Diffusion Visuals from Flopsopoly Sequence

## Priority
Medium

## Current Behavior

The project generates static HTML pages with text-based box-drawing art. No image generation exists beyond syncing existing media attachments from fediverse posts. The word cloud data and flopsopoly sequence (from 13-002) have no visual representation beyond the HTML word cloud page.

## Intended Behavior

After the TTS hypnotic trance track is generated (13-002), produce a sequence of images using a **locally-hosted stable diffusion model** that visually represent the flopsopoly word sequence. Each image's prompt is derived from the **N most recent words** in the flopsopoly, using a **diameter-based context window**.

### Sub-Issues

This issue has been split into the following sub-issues:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| [13-003a](13-003a-implement-diameter-context-window-and-prompt-composition.md) | Implement diameter context window + prompt composition | Open |
| [13-003b](13-003b-implement-stable-diffusion-api-integration.md) | Implement stable diffusion API integration | Open |
| [13-003c](13-003c-implement-single-pass-image-generation-pipeline.md) | Implement single-pass image generation pipeline | Open |
| [13-003d](13-003d-implement-multi-pass-refinement-mode.md) | Implement multi-pass refinement mode (optional) | Open |

**Dependency chain**: 13-003a + 13-003b → 13-003c → 13-003d (optional)

Note: 13-003d (multi-pass) is an optional enhancement and not on the critical path.

### Diameter-Based Context Window

The context window for image generation at position P in the flopsopoly uses a **diameter** centered on the current word — extending equally in both directions:

```
Position P in flopsopoly (total length L):

Context window = [P - N/2, P + N/2]

Where N = configurable context diameter (e.g., 10 words)

Example with N=10 at position P=25:
  Words 20-30 form the prompt for image at position 25

  [20] fire
  [21] silence
  [22] memory    ← backward context (what was just spoken)
  [23] ocean
  [24] dream
  [25] NIGHT     ← current position (center of diameter)
  [26] window
  [27] love      ← forward context (what's coming next)
  [28] silence
  [29] shadow
  [30] garden
```

The **diameter analogy**: just as a circle's diameter extends the same distance (radius) from the center in both directions, the context window extends N/2 words forward and N/2 words backward from the current position. The center point is equidistant from both ends.

At sequence boundaries:
- Near the start (P < N/2): Window is `[0, N]` — more forward context
- Near the end (P > L - N/2): Window is `[L - N, L]` — more backward context

### Image Generation Process

1. **Load flopsopoly manifest** from 13-002 (`output/flopsopoly/sequence.json`)
2. **For each position P** (or every K-th position for frame rate control):
   a. Extract diameter context window: words at `[P - N/2, P + N/2]`
   b. Compose stable diffusion prompt from context words
   c. Call local stable diffusion API to generate image
   d. Save image with positional filename
3. **Output image sequence** for video assembly or slideshow

### Stable Diffusion API Integration

The stable diffusion model runs locally and is accessed via HTTP API (same pattern as Ollama):

```lua
-- Configuration required:
stable_diffusion = {
    endpoint = "http://192.168.0.115:7860",  -- IP address and port (required)
    -- Or:
    endpoint = "http://localhost:7860",

    model = "sd_xl_base_1.0",       -- Model name (configurable)
    width = 1024,
    height = 1024,
    steps = 20,
    cfg_scale = 7.0,
    sampler = "euler_a",
    negative_prompt = "text, watermark, blurry, low quality",
}
```

### Prompt Composition

The context window words are assembled into a stable diffusion prompt:

```lua
-- Simple concatenation:
prompt = "silence fire memory ocean dream night window love"

-- Or with emphasis based on font_size:
-- Words with higher font_size get more emphasis weight
prompt = "(silence:1.4) fire (memory:1.2) ocean dream (night:1.3) window love"

-- Or with semantic color theming:
-- Include the dominant color of the context window
prompt = "blue toned, silence fire memory ocean dream night window love, ethereal"
```

The prompt composition strategy should be explored during implementation.

### Multi-Pass Image Refinement (Optional Toggle)

An optional mode that performs **two or more passes** over the image sequence. On subsequent
passes, the previously generated images are fed back into the stable diffusion context alongside
the words, baking deeper semantic meaning into the visual output.

**How it works:**

1. **Pass 1 (baseline)**: Generate images using only word context (standard diameter window)
2. **Pass 2+ (refinement)**: Generate images using words AND previous-pass images as context

**Image context window** — On refinement passes, the image context reaches **twice as far**
as the word context. If N=4 for words (N/2=2 forward, N/2=2 backward), the image context
uses the full N in each direction (N=4 forward, N=4 backward):

```
Pass 2+ context at position P, with N=4:

  Word context:    [P-2, P+2]   (N/2 each direction = 2+2 = 4 words)
  Image context:   [P-4, P+4]   (N each direction = 4+4 = 8 images from previous pass)

  Why wider? Images from pass 1 already encode the word semantics of their own
  neighborhoods. By reaching further, pass 2 images absorb semantic information
  from a broader region — the previous images carry "pre-digested" meaning that
  propagates through the sequence like a wave.
```

**Weighting**: The inputted images should have roughly the **same weight as the words**
in the AI context. In stable diffusion terms, this means using img2img with the previous
pass image at ~0.5 denoising strength, while the word prompt provides the textual guidance.
Alternatively, if using IP-Adapter or similar, the image embeddings should be weighted
equally with the text embeddings.

**Configuration:**

```lua
multi_pass = {
    enabled = false,          -- Toggle multi-pass mode on/off
    num_passes = 2,           -- Total passes (1 = standard, 2+ = refinement)
    image_context_multiplier = 2,  -- Image reach = N × this multiplier (default: 2×)
    image_weight = 0.5,       -- Weight of previous images vs. words (0-1)
    denoising_strength = 0.5, -- For img2img: how much to change from previous pass
}
```

**Example with 3 passes and N=4:**

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

Each pass compounds the semantic depth — pass 1 images encode local word meaning,
pass 2 images encode local + neighbor meaning, pass 3 images encode local + neighbor +
neighbor-of-neighbor meaning. The semantic field propagates outward with each pass.

**API approach:**

For Automatic1111-style APIs, refinement passes use the `img2img` endpoint instead of `txt2img`:

```lua
-- Pass 1: txt2img (standard)
POST /sdapi/v1/txt2img { prompt = "...", ... }

-- Pass 2+: img2img (with previous pass image + neighbor images as init)
POST /sdapi/v1/img2img {
    prompt = "...",
    init_images = [base64_encoded_previous_pass_images],
    denoising_strength = 0.5,
    ...
}
```

The neighbor images from the previous pass can be composited into a grid or blended
before being passed as the init_image, ensuring all context images contribute equally.

## Technical Design

### Image Generation Pipeline

```lua
-- {{{ local function generate_flopsopoly_visuals
local function generate_flopsopoly_visuals(manifest, config)
    local sequence = manifest.sequence
    local N = config.context_diameter or 10
    local half_N = math.floor(N / 2)
    local frame_interval = config.frame_interval or 1  -- Generate image every K words

    local images_generated = 0

    for p = 1, #sequence, frame_interval do
        -- Compute diameter context window
        local window_start = math.max(1, p - half_N)
        local window_end = math.min(#sequence, p + half_N)

        -- Extract context words
        local context_words = {}
        for i = window_start, window_end do
            table.insert(context_words, sequence[i].word)
        end

        -- Compose prompt
        local prompt = compose_prompt(context_words, config)

        -- Call stable diffusion API
        local image_path = string.format("%s/frame_%06d.png", config.output_dir, p)
        local success = call_stable_diffusion(prompt, image_path, config)

        if success then
            images_generated = images_generated + 1
            io.write(string.format("\rGenerated frame %d/%d", images_generated, math.ceil(#sequence / frame_interval)))
            io.flush()
        end
    end

    return images_generated
end
-- }}}
```

### Stable Diffusion API Call

```lua
-- {{{ local function call_stable_diffusion
-- Calls local stable diffusion API via HTTP POST
-- Uses the same curl pattern as Ollama integration
local function call_stable_diffusion(prompt, output_path, config)
    local endpoint = config.endpoint
    local payload = {
        prompt = prompt,
        negative_prompt = config.negative_prompt or "",
        width = config.width or 1024,
        height = config.height or 1024,
        steps = config.steps or 20,
        cfg_scale = config.cfg_scale or 7.0,
        sampler_name = config.sampler or "euler_a",
    }

    local payload_json = dkjson.encode(payload)
    local temp_file = DIR .. "/tmp/sd_request.json"
    utils.write_file(temp_file, payload_json)

    -- Call API (Automatic1111 or ComfyUI format)
    local cmd = string.format(
        'curl -s -X POST "%s/sdapi/v1/txt2img" -H "Content-Type: application/json" -d @%s',
        endpoint, temp_file
    )

    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()

    -- Parse response and save image
    local data = dkjson.decode(response)
    if data and data.images and data.images[1] then
        -- Decode base64 image and save
        save_base64_image(data.images[1], output_path)
        return true
    end

    return false
end
-- }}}
```

### Configuration

```lua
-- In config.lua:
stable_diffusion = {
    -- Connection (required)
    endpoint = "",  -- Must be configured: "http://IP:PORT"

    -- Model settings
    width = 1024,
    height = 1024,
    steps = 20,
    cfg_scale = 7.0,
    sampler = "euler_a",
    negative_prompt = "text, watermark, blurry, low quality, deformed",

    -- Flopsopoly visual settings
    context_diameter = 10,      -- N: words in context window (diameter)
    frame_interval = 1,         -- Generate image every K words
    prompt_style = "weighted",  -- "simple", "weighted", or "themed"
    include_color_theme = true, -- Add semantic color to prompt

    -- Multi-pass refinement (optional)
    multi_pass = {
        enabled = false,              -- Toggle on/off
        num_passes = 2,               -- Total passes (1 = single, 2+ = refinement)
        image_context_multiplier = 2, -- Image reach = N × multiplier per direction
        image_weight = 0.5,           -- Weight of previous images vs words (0-1)
        denoising_strength = 0.5,     -- img2img denoising (lower = more faithful to prev)
    },
}
```

### CLI Integration

```bash
# In run.sh:
--sd-endpoint URL       # Stable diffusion API endpoint (required for 13-003)
--sd-context N          # Context diameter for image prompts (default: 10)
--sd-interval K         # Generate image every K words (default: 1)
--sd-multi-pass         # Enable multi-pass refinement mode
--sd-passes N           # Number of passes (default: 2, requires --sd-multi-pass)
```

## Output Structure

```
output/
├── trance-track.wav                    # From 13-002
├── trance-track-manifest.json          # From 13-002
├── flopsopoly/
│   ├── sequence.json                   # From 13-002
│   ├── audio-cache/                    # From 13-002
│   └── visuals/
│       ├── pass1/                      # Single-pass output (or pass 1 of multi-pass)
│       │   ├── frame_000001.png
│       │   ├── frame_000002.png
│       │   ├── ...
│       │   └── frame_000742.png
│       ├── pass2/                      # Multi-pass only: refinement pass 2
│       │   ├── frame_000001.png
│       │   └── ...
│       ├── pass3/                      # Multi-pass only: refinement pass 3
│       │   └── ...
│       ├── final/                      # Symlinks or copies of the final pass output
│       │   ├── frame_000001.png → ../pass2/frame_000001.png
│       │   └── ...
│       └── visual-manifest.json        # Image metadata, prompts, and pass info
```

### Visual Manifest

```json
{
    "frames": [
        {
            "position": 1,
            "center_word": "silence",
            "context_words": ["silence", "fire", "memory", "ocean", "dream"],
            "prompt": "(silence:1.4) fire (memory:1.2) ocean dream",
            "image_file": "frame_000001.png",
            "audio_start_ms": 0,
            "audio_end_ms": 620
        }
    ],
    "total_frames": 742,
    "context_diameter": 10,
    "model": "sd_xl_base_1.0"
}
```

## Validation

- Each generated image should exist as a valid PNG file
- The visual manifest should have timestamps matching the audio manifest from 13-002
- Context windows should be correct at boundaries (start/end of sequence)
- The stable diffusion endpoint should be validated before starting generation
- A test mode should generate 5 sample images before committing to full sequence

## Edge Cases

- **Stable diffusion endpoint unavailable**: Error immediately with helpful message (no fallback)
- **API timeout**: Retry once, then skip frame with log entry
- **Context window at boundaries**: Clamp to `[1, L]` — asymmetric window is acceptable
- **Very large sequence** (>1000 frames): Estimate time and warn user (each frame ~5-30 seconds)
- **Disk space**: Estimate storage needed (e.g., 742 images × ~2MB = ~1.5GB)

## Performance Notes

Image generation is the bottleneck:
- Per image: 5-30 seconds (depending on model, steps, resolution)
- For 742 frames at 10s/frame: ~2 hours
- Consider `frame_interval > 1` to reduce count (e.g., every 3rd word = ~250 frames = ~40 min)
- Images are embarrassingly parallel if multiple SD instances are available

## Original Request Context

> Okay now can we make an issue file in a new phase, a phase related to audio generation from similar/different embedding similarity matrix identity convolutional declarative iteration style programming? The first issue file should be about researching and implementing a TTS engine. The first todo item in that issue file should be to split the file into sub-issues, for research, design, and implementation. The next issue file should be about passing all the words from the word-cloud generator through a TTS, with the frequency of each word corresponding to the "size" of the word in the word cloud. If the base size is 1, and there's a word with size 7, then 7 instances of that word will be placed in the pool of words to iterate through with the TTS engine. These 7 instances will be pseudo-deterministically ordered in a big pool of words, a flopsopoly of verbrases if you will. This flopsopoly will be ordered in the way that makes the most sense, as determined by a progressively expanding centroid calculation that calculates the most distant word from among all of the remaining words. Since there are duplicate words by design, it will add one of the duplicates to the centroid which will then reduce the likelihood that the centroid (selecting the most distant word) will select that word again until the centralized cluster has been shifted enough that the already-selected-word is now the farthest. This should provide for an interesting hypnotic experience that can be matched to visuals created by a locally run stable diffusion model (IP address and port required) which creates images based on a flopsopoly of verbrases that correspond to the N most recent words that have been added to the flopsopoly. Note that N is taken from the forward and backwards directions, like a diameter is the same distance from the central point at both ends as the radius of a circle might be. The images will be created after the TTS hypnotic trance track has been generated, which means the image related functionality should be another issue. Please include this message in all of the issue files for further reference.

## Related Documents

- Issue 13-001: Research and Implement TTS Engine (upstream dependency)
- Issue 13-002: Generate TTS Hypnotic Trance Track (provides manifest and audio)
- `libs/ollama-config.lua` — Reference for local API service integration pattern
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — Word embeddings for prompt weighting

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: High (API integration + prompt engineering + large-scale generation)
- **Dependencies**: 13-001 (TTS engine), 13-002 (flopsopoly manifest and audio)
