# Issue 10-022: Fix Empty Embeddings Validation

## Status: COMPLETED

## Current Behavior

When the embeddings.json file exists but contains an empty `embeddings` array (e.g., due to failed embedding generation from network errors), the GPU similarity module crashes with:

```
luajit: libs/vulkan-compute/lua/vk_similarity.lua:273: attempt to index a nil value
```

And the generate-embeddings.sh script crashes with:

```
lua: (command line):42: bad argument #6 to 'format' (not a number in proper range)
```

The root cause is that embedding generation failed (due to Ollama network errors), leaving an empty embeddings array:

```json
{
  "embeddings":[],
  "metadata":{
    "processing_mode":"terminated_network_error",
    "completed_embeddings":0,
    "termination_reason":"consecutive_network_errors"
  }
}
```

## Intended Behavior

1. GPU similarity module should detect empty embeddings and provide clear error message with remediation steps
2. generate-embeddings.sh should handle zero embeddings without division by zero errors
3. Error messages should explain the root cause (network failure) and how to fix it

## Implementation

### vk_similarity.lua (lines 266-287)

Added validation after loading embeddings:

```lua
local num_poems = #embeddings_data.embeddings
-- Validate embeddings array is non-empty before accessing first element
-- Empty arrays occur when embedding generation failed (network errors, etc.)
if num_poems == 0 then
    local reason = embeddings_data.metadata and embeddings_data.metadata.termination_reason or "unknown"
    local mode = embeddings_data.metadata and embeddings_data.metadata.processing_mode or "unknown"
    error(string.format(
        "[GPU SIMILARITY ERROR] Embeddings array is empty (0 poems).\n" ..
        "  Processing mode: %s\n" ..
        "  Termination reason: %s\n" ..
        "  Remedy: Regenerate embeddings with: ./run.sh --generate-embeddings --force\n" ..
        "  Ensure Ollama is running: ollama serve",
        mode, reason
    ))
end
```

Same fix applied to both:
- `generate_similarity_matrix_gpu_parallel()` (line 260)
- `generate_similarity_matrix_gpu()` (line 539, deprecated sequential version)

### generate-embeddings.sh (lines 811-819)

Added guards against division by zero in statistics calculation:

```lua
-- Guard against division by zero when embeddings array is empty
local success_rate = 0
if total > 0 then
    success_rate = math.floor((successful / total) * 100)
end
local processing_rate = 0
if $TOTAL_TIME > 0 then
    processing_rate = math.floor(successful * 3600 / $TOTAL_TIME)
end
```

## Files Modified

- `libs/vulkan-compute/lua/vk_similarity.lua` - Added empty array validation with descriptive error
- `generate-embeddings.sh`:
  - Added division by zero guards in statistics calculation
  - Changed from piped stdin (`echo | lua -I`) to direct function call via `luajit -e`
    - The piped stdin caused curl exit code 7 (connection refused) due to file descriptor inheritance issues
  - Added explicit failure detection when `SUCCESSFUL=0` or `processing_mode=terminated_network_error`
    - Previously would show "GENERATION SUCCESSFUL" even when 0 embeddings were created

## Lessons Learned

1. Always validate array bounds before accessing elements, especially when loading external data
2. Division operations need guards when denominators can be zero
3. Error messages should include context from metadata (like `termination_reason`) to help diagnosis
4. The "attempt to index a nil value" error in Lua often indicates array bounds issues
5. **Piped stdin can cause subprocess failures**: When running `echo "input" | lua script.lua`, the script's child processes (like `curl` via `io.popen`) can fail with exit code 7 (connection refused) due to inherited file descriptors
6. Use direct function calls (`luajit -e "require('module').function()"`) instead of piped interactive modes when calling from scripts
7. Success messages should verify actual results, not just exit codes - a script can exit 0 but produce 0 useful outputs

## Related Issues

- 8-004: Implement embedding validation and empty poem handling
- 10-017: Multi-Ollama server configuration (network connectivity)

## Completed

2026-02-10
