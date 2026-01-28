# Issue 13-003b: Implement Stable Diffusion API Integration

## Priority
High (blocks 13-003c)

## Parent Issue
13-003: Generate Stable Diffusion Visuals from Flopsopoly Sequence

## Current Behavior

The project integrates with Ollama for embeddings via HTTP API (`libs/ollama-config.lua`). No stable diffusion integration exists. The user has a locally-hosted stable diffusion instance available at a configurable IP:port.

## Intended Behavior

Implement a Lua wrapper module for calling a local stable diffusion API (Automatic1111/SDAPI or ComfyUI format) to generate images from text prompts.

### API Patterns

**Automatic1111 Web UI API** (most common):
```
POST http://IP:PORT/sdapi/v1/txt2img
Content-Type: application/json

{
    "prompt": "silence fire memory ocean dream",
    "negative_prompt": "text, watermark, blurry",
    "width": 1024,
    "height": 1024,
    "steps": 20,
    "cfg_scale": 7.0,
    "sampler_name": "euler_a"
}

Response:
{
    "images": ["base64_encoded_png_data"],
    "parameters": {...},
    "info": "..."
}
```

**ComfyUI API** (alternative):
```
POST http://IP:PORT/prompt
{
    "prompt": { ... workflow JSON ... }
}
```

For this issue, focus on Automatic1111 API as the primary target. ComfyUI support can be a future enhancement.

### Lua Wrapper Interface

```lua
-- libs/stable-diffusion.lua

-- {{{ sd.init
-- Initialize stable diffusion client with configuration
-- @param config: table with endpoint, model settings
-- @return boolean success, string error_message
local function init(config)
end
-- }}}

-- {{{ sd.txt2img
-- Generate image from text prompt
-- @param prompt: string prompt for image generation
-- @param output_path: path to save generated image
-- @param options: optional overrides for width, height, steps, etc.
-- @return boolean success, string error_message
local function txt2img(prompt, output_path, options)
end
-- }}}

-- {{{ sd.img2img
-- Generate image from text prompt + input image (for multi-pass)
-- @param prompt: string prompt for image generation
-- @param init_image_path: path to input image
-- @param output_path: path to save generated image
-- @param options: denoising_strength, etc.
-- @return boolean success, string error_message
local function img2img(prompt, init_image_path, output_path, options)
end
-- }}}

-- {{{ sd.check_connection
-- Verify stable diffusion API is reachable
-- @return boolean connected, string error_message
local function check_connection()
end
-- }}}
```

### Configuration

```lua
-- In config.lua:
stable_diffusion = {
    -- Connection (required)
    endpoint = "",  -- Must be configured: "http://192.168.0.115:7860"

    -- Model settings
    width = 1024,
    height = 1024,
    steps = 20,
    cfg_scale = 7.0,
    sampler = "euler_a",
    negative_prompt = "text, watermark, blurry, low quality, deformed",

    -- Timeouts
    timeout_seconds = 120,  -- Per-image generation timeout
    retry_on_timeout = true,
    max_retries = 2,
}
```

## Technical Design

### HTTP Request via curl

Follow the Ollama integration pattern using curl:

```lua
-- {{{ local function call_txt2img_api
local function call_txt2img_api(prompt, config)
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
    local temp_request = DIR .. "/tmp/sd_request.json"
    local temp_response = DIR .. "/tmp/sd_response.json"

    utils.write_file(temp_request, payload_json)

    local cmd = string.format(
        'curl -s -X POST "%s/sdapi/v1/txt2img" ' ..
        '-H "Content-Type: application/json" ' ..
        '-d @"%s" ' ..
        '--max-time %d ' ..
        '-o "%s"',
        config.endpoint,
        temp_request,
        config.timeout_seconds or 120,
        temp_response
    )

    local exit_code = os.execute(cmd)
    if exit_code ~= 0 then
        return nil, "curl failed with exit code: " .. tostring(exit_code)
    end

    local response_text = utils.read_file(temp_response)
    if not response_text then
        return nil, "Failed to read response file"
    end

    local response = dkjson.decode(response_text)
    if not response or not response.images or not response.images[1] then
        return nil, "Invalid response: no images returned"
    end

    return response.images[1]  -- Base64 encoded image
end
-- }}}
```

### Base64 Image Decoding

Stable diffusion returns images as base64-encoded PNG. Decode and save:

```lua
-- {{{ local function save_base64_image
local function save_base64_image(base64_data, output_path)
    -- Use base64 command-line tool for decoding
    local temp_b64 = DIR .. "/tmp/image.b64"
    utils.write_file(temp_b64, base64_data)

    local cmd = string.format(
        'base64 -d "%s" > "%s"',
        temp_b64, output_path
    )

    local exit_code = os.execute(cmd)
    return exit_code == 0
end
-- }}}
```

### Connection Check

```lua
-- {{{ local function check_connection
local function check_connection(config)
    local cmd = string.format(
        'curl -s -o /dev/null -w "%%{http_code}" "%s/sdapi/v1/options" --max-time 5',
        config.endpoint
    )

    local handle = io.popen(cmd)
    local status_code = handle:read("*a")
    handle:close()

    if status_code == "200" then
        return true, nil
    else
        return false, "API returned status: " .. status_code
    end
end
-- }}}
```

## Suggested Implementation Steps

1. **Create `libs/stable-diffusion.lua`** — Module skeleton with vimfolds
2. **Implement `check_connection()`** — Verify API reachability
3. **Implement `txt2img(prompt, output_path, options)`** — Core generation
4. **Implement `img2img(prompt, init_image_path, output_path, options)`** — For multi-pass (13-003d)
5. **Add base64 decoding** — Save returned images as PNG files
6. **Add retry logic** — Handle timeouts and transient failures
7. **Add configuration schema** — `stable_diffusion` section in `config.lua`
8. **Create test script** — Generate a single test image
9. **Document in `libs/stable-diffusion.info.md`**

## Deliverables

- [ ] `libs/stable-diffusion.lua` — API wrapper module
- [ ] `libs/stable-diffusion.info.md` — Interface documentation
- [ ] `check_connection()` — API health check
- [ ] `txt2img()` — Text-to-image generation
- [ ] `img2img()` — Image-to-image generation (for 13-003d)
- [ ] Base64 decoding and image saving
- [ ] Retry logic for timeouts
- [ ] Configuration schema in `config.lua`
- [ ] Test script: `scripts/test-stable-diffusion.sh`

## Testing

```lua
-- Test: connection check
local connected, err = sd.check_connection()
assert(connected, "Failed to connect: " .. (err or "unknown"))

-- Test: generate single image
local success, err = sd.txt2img(
    "a peaceful sunset over mountains, digital art",
    "tmp/test_image.png",
    {steps = 10}  -- Faster for testing
)
assert(success, "txt2img failed: " .. (err or "unknown"))
assert(file_exists("tmp/test_image.png"), "Output image not created")

-- Test: verify image is valid PNG
local handle = io.popen('file tmp/test_image.png')
local file_type = handle:read("*a")
handle:close()
assert(file_type:find("PNG"), "Output is not a valid PNG")
```

## Error Handling

| Error | Behavior |
|-------|----------|
| Endpoint not configured | Error immediately: "stable_diffusion.endpoint not configured" |
| API unreachable | Error with connection details, suggest checking IP:port |
| Timeout | Retry once (if configured), then error with timeout duration |
| Invalid response | Error with response snippet for debugging |
| Base64 decode failure | Error with decode command output |

## Edge Cases

- **Endpoint without protocol**: Auto-prepend "http://" if missing
- **Trailing slash**: Normalize endpoint URL
- **Very large images**: Warn if width/height > 2048 (slow generation)
- **Empty prompt**: Error immediately (SD may hang or error)

## Related Documents

- Issue 13-003: Generate Stable Diffusion Visuals (parent)
- Issue 13-003a: Implement Diameter Context Window and Prompt Composition (provides prompts)
- Issue 13-003c: Implement Single-Pass Image Generation Pipeline (uses this module)
- Issue 13-003d: Implement Multi-Pass Refinement Mode (uses img2img)
- `libs/ollama-config.lua` — Reference for local API integration pattern

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (HTTP API integration)
- **Dependencies**: Local stable diffusion instance running
- **Blocks**: 13-003c, 13-003d
